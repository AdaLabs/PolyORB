------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                 POLYORB.ORB_CONTROLLER.LEADER_FOLLOWERS                  --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2004 Free Software Foundation, Inc.             --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

with PolyORB.Annotations;
with PolyORB.Asynch_Ev;
with PolyORB.Constants;
with PolyORB.Initialization;
pragma Elaborate_All (PolyORB.Initialization); --  WAG:3.15

with PolyORB.Log;
with PolyORB.Parameters;
with PolyORB.Tasking.Threads.Annotations;
with PolyORB.Utils.Strings;

package body PolyORB.ORB_Controller.Leader_Followers is

   use PolyORB.Annotations;
   use PolyORB.Jobs;
   use PolyORB.Log;
   use PolyORB.Task_Info;
   use PolyORB.Tasking.Condition_Variables;
   use PolyORB.Tasking.Mutexes;
   use PolyORB.Tasking.Threads;
   use PolyORB.Tasking.Threads.Annotations;

   package L is
      new PolyORB.Log.Facility_Log
     ("polyorb.orb_controller.leader_followers");
   procedure O1 (Message : in String; Level : Log_Level := Debug)
     renames L.Output;

   package L2 is
      new PolyORB.Log.Facility_Log ("polyorb.orb_controller_status");
   procedure O2 (Message : in String; Level : Log_Level := Debug)
     renames L2.Output;

   function Allocate_CV
     (O : access ORB_Controller_Leader_Followers)
     return Condition_Access;
   --  Return one CV.

   procedure Awake_One_Idle_Task
     (O : access ORB_Controller_Leader_Followers);
   --  Awake one idle task, if any. Else raise Program_Error.

   procedure Try_Allocate_One_Task
     (O : access ORB_Controller_Leader_Followers);
   --  Awake one idle task, if any. Else do nothing.

   type LF_Task_Note is new PolyORB.Annotations.Note with record
      TI  : Thread_Id;
      Job : Job_Access;
   end record;

   -------------------
   -- Register_Task --
   -------------------

   procedure Register_Task
     (O  : access ORB_Controller_Leader_Followers;
      TI :        PTI.Task_Info_Access)
   is
   begin
      pragma Debug (O1 ("Register_Task: enter"));

      pragma Assert (State (TI.all) = Unscheduled);

      O.Registered_Tasks := O.Registered_Tasks + 1;
      O.Unscheduled_Tasks := O.Unscheduled_Tasks + 1;

      Set_Note (Get_Current_Thread_Notepad.all,
                LF_Task_Note'(Note with TI => Id (TI.all), Job => null));

      pragma Debug (O2 (Status (O)));
      pragma Debug (O1 ("Register_Task: leave"));
   end Register_Task;

   ---------------------
   -- Disable_Polling --
   ---------------------

   procedure Disable_Polling (O : access ORB_Controller_Leader_Followers) is
   begin

      --  Force all tasks currently waiting on event sources to abort

      if O.Blocked_Tasks > 0 then

         --  In this implementation, only one task may be blocked on
         --  event sources. We abort it.

         pragma Debug (O1 ("Disable_Polling: Aborting polling task"));
         PTI.Request_Abort_Polling (O.Blocked_Task_Info.all);
         PolyORB.Asynch_Ev.Abort_Check_Sources
           (Selector (O.Blocked_Task_Info.all).all);

         pragma Debug (O1 ("Disable_Polling: waiting abort is complete"));
         O.Polling_Abort_Counter := O.Polling_Abort_Counter + 1;
         Wait (O.Polling_Completed, O.ORB_Lock);
         O.Polling_Abort_Counter := O.Polling_Abort_Counter - 1;

         pragma Debug (O1 ("Disable_Polling: aborting done"));
      end if;
   end Disable_Polling;

   --------------------
   -- Enable_Polling --
   --------------------

   procedure Enable_Polling (O : access ORB_Controller_Leader_Followers) is
   begin
      if O.Polling_Abort_Counter = 0 then

         --  Allocate one task to poll on AES

         Try_Allocate_One_Task (O);
      end if;
   end Enable_Polling;

   ------------------
   -- Notify_Event --
   ------------------

   procedure Notify_Event
     (O : access ORB_Controller_Leader_Followers;
      E :        Event)
   is
      use type PAE.Asynch_Ev_Monitor_Access;
      use type PRS.Request_Scheduler_Access;
      use type PolyORB.Tasking.Threads.Thread_Id;

   begin
      pragma Debug (O1 ("Notify_Event: " & Event_Kind'Image (E.Kind)));

      case E.Kind is

         when End_Of_Check_Sources =>

            --  A task completed polling on a monitor

            O.Blocked_Tasks := O.Blocked_Tasks - 1;
            O.Unscheduled_Tasks := O.Unscheduled_Tasks + 1;

            O.Blocked_Task_Info := null;

            if O.Polling_Abort_Counter > 0 then

               --  This task has been aborted by one or more tasks, we
               --  broadcast them.

               Broadcast (O.Polling_Completed);
            end if;

         when Event_Sources_Added =>

            --  An AES has been added to monitored AES list

            O.Number_Of_AES := O.Number_Of_AES + 1;

            if O.Monitors (1) = null then

               --  There was no monitor registred yet, register new monitor

               O.Monitors (1) := E.Add_In_Monitor;

            else

               --  Under this implementation, there can be at most one
               --  monitor. Ensure this assertion is correct.

               pragma Assert (E.Add_In_Monitor = O.Monitors (1));
               null;
            end if;

            if O.Blocked_Tasks = 0
              and then not O.Polling_Scheduled
            then

               --  No task is currently polling, allocate one.

               O.Polling_Scheduled := True;
               Try_Allocate_One_Task (O);
            end if;

         when Event_Sources_Deleted =>

            --  An AES has been removed from monitored AES list

            pragma Assert (O.Monitors (1) /= null);

            null;

         when Job_Completed =>

            --  A task has completed the execution of a job

            O.Running_Tasks := O.Running_Tasks - 1;
            O.Unscheduled_Tasks := O.Unscheduled_Tasks + 1;

         when ORB_Shutdown =>

            --  ORB shutdown has been requested

            O.Shutdown := True;

            --  Awake all idle tasks

            for J in 1 .. O.Idle_Tasks loop
               Awake_One_Idle_Task (O);
            end loop;

            --  Unblock blocked tasks

            if O.Blocked_Tasks > 0 then

               PTI.Request_Abort_Polling (O.Blocked_Task_Info.all);
               PolyORB.Asynch_Ev.Abort_Check_Sources
                 (Selector (O.Blocked_Task_Info.all).all);
            end if;

         when Queue_Event_Job =>

            declare
               Note : LF_Task_Note;

            begin
               Get_Note (Get_Current_Thread_Notepad.all, Note);

               if Note.TI = E.By_Task
                 and then Note.Job = null
               then

                  --  Queue event directly into task attribute

                  Set_Note
                    (Get_Current_Thread_Notepad.all,
                     LF_Task_Note'(Annotations.Note
                                   with TI => E.By_Task, Job => E.Event_Job));
               else

                  --  Queue event to main job queue

                  PJ.Queue_Job (O.Job_Queue, E.Event_Job);
                  Try_Allocate_One_Task (O);
               end if;
            end;

         when Queue_Request_Job =>

            if O.RS = null
              or else not PRS.Try_Queue_Request_Job
              (O.RS, E.Request_Job, E.Target)
            then

               --  Queue event to main job queue

               declare
                  Note : LF_Task_Note;

               begin
                  Get_Note
                    (Get_Current_Thread_Notepad.all,
                     Note);

                  if Note.TI = Current_Task
                    and then Note.Job = null
                  then
                     --  Queue event directly into task attribute

                     pragma Debug (O1 ("Queue request in task area"));

                     Set_Note
                       (Get_Current_Thread_Notepad.all,
                        LF_Task_Note'(Annotations.Note
                                      with TI => Note.TI,
                                      Job => E.Request_Job));
                  else
                     O.Number_Of_Pending_Jobs := O.Number_Of_Pending_Jobs + 1;
                     PJ.Queue_Job (O.Job_Queue, E.Request_Job);
                     Try_Allocate_One_Task (O);
                  end if;
               end;
            end if;

         when Request_Result_Ready =>

            --  A Request has been completed and a resonse is
            --  available. We must forward it to requesting task. We
            --  ensure this task will stop its current action and ask
            --  for rescheduling.

            case State (E.Requesting_Task.all) is
               when Running =>

                  --  We cannot abort a running task. We let it
                  --  complete its job and ask for rescheduling.

                  null;

               when Blocked =>

                  --  We abort this task. It will then leave Blocked
                  --  state and ask for rescheduling.

                  declare
                     use PolyORB.Asynch_Ev;

                     Sel : Asynch_Ev_Monitor_Access
                       renames Selector (E.Requesting_Task.all);

                  begin
                     pragma Debug (O1 ("About to abort block"));

                     pragma Assert (Sel /= null);
                     Abort_Check_Sources (Sel.all);

                     pragma Debug (O1 ("Aborted."));
                  end;

               when Idle =>

                  --  We awake this task. It will then leave Idle
                  --  state and ask for rescheduling.

                  pragma Debug (O1 ("Signal requesting task"));

                  Signal (Condition (E.Requesting_Task.all));

               when Terminated
                 | Unscheduled =>

                  --  Nothing to do

                  null;
            end case;

         when Idle_Awake =>

            O.Idle_Tasks := O.Idle_Tasks - 1;
            O.Unscheduled_Tasks := O.Unscheduled_Tasks + 1;

            List_Detach (E.Awakened_Task.all, O.Idle_Task_List);

      end case;

      pragma Debug (O2 (Status (O)));
   end Notify_Event;

   -------------------
   -- Schedule_Task --
   -------------------

   procedure Schedule_Task
     (O  : access ORB_Controller_Leader_Followers;
      TI :        PTI.Task_Info_Access)
   is
      Note : LF_Task_Note;

   begin
      pragma Debug (O1 ("Schedule_Task " & PTI.Image (TI.all) & ": enter"));

      pragma Assert (PTI.State (TI.all) = Unscheduled);

      Get_Note (Get_Current_Thread_Notepad.all, Note);

      --  Recompute TI status

      if Exit_Condition (TI.all)
        or else O.Shutdown
      then

         O.Unscheduled_Tasks := O.Unscheduled_Tasks - 1;
         O.Terminated_Tasks := O.Terminated_Tasks + 1;

         Set_State_Terminated (TI.all);

         pragma Debug (O1 ("Task is now terminated"));
         pragma Debug (O2 (Status (O)));

      elsif Note.Job /= null then

         --  Process locally queued job

         O.Unscheduled_Tasks := O.Unscheduled_Tasks - 1;
         O.Running_Tasks := O.Running_Tasks + 1;

         declare
            Job : constant Job_Access := Note.Job;

         begin
            Set_Note
              (Get_Current_Thread_Notepad.all,
               LF_Task_Note'(Annotations.Note
                             with TI => Note.TI, Job => null));

            Set_State_Running (TI.all, Job);
         end;

      elsif not PJ.Is_Empty (O.Job_Queue) then

         --  Process job

         O.Unscheduled_Tasks := O.Unscheduled_Tasks - 1;
         O.Running_Tasks := O.Running_Tasks + 1;

         Set_State_Running (TI.all, PJ.Fetch_Job (O.Job_Queue));

      elsif May_Poll (TI.all)
        and then O.Number_Of_AES > 0
        and then O.Polling_Abort_Counter = 0
        and then O.Blocked_Tasks = 0
      then

         O.Unscheduled_Tasks := O.Unscheduled_Tasks - 1;
         O.Blocked_Tasks := O.Blocked_Tasks + 1;

         O.Polling_Scheduled := False;

         O.Blocked_Task_Info := TI;

         Set_State_Blocked
           (TI.all,
            O.Monitors (1),
            O.Polling_Timeout);

         pragma Debug (O1 ("Task is now blocked"));
         pragma Debug (O2 (Status (O)));

      else

         --  Go idle

         O.Unscheduled_Tasks := O.Unscheduled_Tasks - 1;
         O.Idle_Tasks := O.Idle_Tasks + 1;

         Set_State_Idle (TI.all, Allocate_CV (O), O.ORB_Lock);
         Idle_Task_Lists.Append (O.Idle_Task_List, TI);
         List_Attach (TI.all, Task_Lists.First (O.Idle_Task_List));

         pragma Debug (O1 ("Task is now idle"));
         pragma Debug (O2 (Status (O)));

      end if;
   end Schedule_Task;

   ---------------------
   -- Unregister_Task --
   ---------------------

   procedure Unregister_Task
     (O  : access ORB_Controller_Leader_Followers;
      TI :        PTI.Task_Info_Access)
   is
   begin
      pragma Debug (O1 ("Unregister_Task: enter"));

      pragma Assert (State (TI.all) = Terminated);

      O.Terminated_Tasks := O.Terminated_Tasks - 1;
      O.Registered_Tasks := O.Registered_Tasks - 1;

      pragma Debug (O2 (Status (O)));
      pragma Debug (O1 ("Unregister_Task: leave"));
   end Unregister_Task;

   -----------------
   -- Allocate_CV --
   -----------------

   function Allocate_CV
     (O : access ORB_Controller_Leader_Followers)
     return Condition_Access
   is
      use type CV_Lists.List;

      Result : Condition_Access;

   begin
      if O.Free_CV /= CV_Lists.Empty then

         --  Use an existing CV, from Free_CV list

         CV_Lists.Extract_First (O.Free_CV, Result);
      else

         --  else allocate a new one

         Create (Result);
      end if;

      return Result;
   end Allocate_CV;

   -------------------------
   -- Awake_One_Idle_Task --
   -------------------------

   procedure Awake_One_Idle_Task
     (O : access ORB_Controller_Leader_Followers)
   is
      use Idle_Task_Lists;

      Task_To_Awake : Task_Info_Access;

   begin
      if O.Idle_Task_List /= Empty then
         pragma Debug (O1 ("Awake one idle task"));

         --  Signal one idle task, and puts its CV in Free_CV

         Idle_Task_Lists.Extract_First (O.Idle_Task_List, Task_To_Awake);
         List_Attach (Task_To_Awake.all, Task_Lists.Last (O.Idle_Task_List));
         Signal (Condition (Task_To_Awake.all));
         CV_Lists.Append (O.Free_CV, Condition (Task_To_Awake.all));

      end if;
   end Awake_One_Idle_Task;

   ---------------------------
   -- Try_Allocate_One_Task --
   ---------------------------

   procedure Try_Allocate_One_Task
     (O : access ORB_Controller_Leader_Followers)
   is
   begin

      pragma Debug (O1 ("Try_Allocate_One_Task: enter"));

      if O.Unscheduled_Tasks > 0 then
         --  Some tasks are not scheduled. We assume one of them will
         --  be allocated to handle current event.

         pragma Debug (O1 ("Assume one unaffected task will handle event"));
         null;

      elsif O.Idle_Tasks > 0 then

         Awake_One_Idle_Task (O);

      else
         pragma Debug (O1 ("No idle tasks"));
         null;

      end if;

      pragma Debug (O1 ("Try_Allocate_One_Task: end"));
   end Try_Allocate_One_Task;

   --------------------------------
   -- Enter_ORB_Critical_Section --
   --------------------------------

   procedure Enter_ORB_Critical_Section
     (O : access ORB_Controller_Leader_Followers)
   is
   begin
      PTM.Enter (O.ORB_Lock);
   end Enter_ORB_Critical_Section;

   --------------------------------
   -- Leave_ORB_Critical_Section --
   --------------------------------

   procedure Leave_ORB_Critical_Section
     (O : access ORB_Controller_Leader_Followers)
   is
   begin
      PTM.Leave (O.ORB_Lock);
   end Leave_ORB_Critical_Section;

   ----------------------
   -- Is_A_Job_Pending --
   ----------------------

   function Is_A_Job_Pending
     (O : access ORB_Controller_Leader_Followers)
     return Boolean
   is
   begin
      return not PJ.Is_Empty (O.Job_Queue);
   end Is_A_Job_Pending;

   ---------------------
   -- Get_Pending_Job --
   ---------------------

   function Get_Pending_Job
     (O : access ORB_Controller_Leader_Followers)
     return PJ.Job_Access
   is
   begin
      pragma Assert (Is_A_Job_Pending (O));
      O.Number_Of_Pending_Jobs := O.Number_Of_Pending_Jobs - 1;

      return PJ.Fetch_Job (O.Job_Queue);
   end Get_Pending_Job;

   ------------------
   -- Get_Monitors --
   ------------------

   function Get_Monitors
     (O : access ORB_Controller_Leader_Followers)
     return Monitor_Array
   is
      use type PAE.Asynch_Ev_Monitor_Access;

   begin
      if O.Monitors (1) /= null then
         return O.Monitors;
      else
         return Monitor_Array'(1 .. 0 => null);
      end if;
   end Get_Monitors;

   ------------
   -- Create --
   ------------

   function Create
     (OCF : access ORB_Controller_Leader_Followers_Factory)
     return ORB_Controller_Access
   is
      use PolyORB.Parameters;

      pragma Warnings (Off);
      pragma Unreferenced (OCF);
      pragma Warnings (On);

      OC : ORB_Controller_Leader_Followers_Access;
      RS : PRS.Request_Scheduler_Access;

      Polling_Interval : constant Natural
        := Get_Conf ("orb_controller",
                     "polyorb.orb_controller_basic.polling_interval",
                     0);

      Polling_Timeout : constant Natural
        := Get_Conf ("orb_controller",
                     "polyorb.orb_controller_basic.polling_timeout",
                     0);

   begin
      PRS.Create (RS);
      OC := new ORB_Controller_Leader_Followers (RS);

      Create (OC.ORB_Lock);
      Create (OC.Polling_Completed);
      OC.Job_Queue := PolyORB.Jobs.Create_Queue;

      if Polling_Interval = 0 then
         OC.Polling_Interval := PolyORB.Constants.Forever;
      else
         OC.Polling_Interval := Polling_Interval * 0.01;
      end if;

      if Polling_Timeout = 0 then
         OC.Polling_Timeout := PolyORB.Constants.Forever;
      else
         OC.Polling_Timeout := Polling_Timeout * 0.01;
      end if;

      return ORB_Controller_Access (OC);
   end Create;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize;

   procedure Initialize is
   begin
      Register_ORB_Controller_Factory (OCF);
   end Initialize;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;
   use PolyORB.Utils.Strings;

begin
   Register_Module
     (Module_Info'
      (Name      => +"orb_controller.leader_followers",
       Conflicts => +"orb.no_tasking",
       Depends   => +"tasking.condition_variables"
       &"tasking.mutexes"
       & "request_scheduler?",
       Provides  => +"orb_controller",
       Implicit  => False,
       Init      => Initialize'Access));
end PolyORB.ORB_Controller.Leader_Followers;
