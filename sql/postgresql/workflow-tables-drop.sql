-- Drop table data for the workflow package, part of the OpenACS system.
--
-- @author Lars Pind (lars@collaboraid.biz)
-- @author Peter Marklund (peter@collaboraid.biz)
-- @creation-date 9 Januar 2003
--
-- This is free software distributed under the terms of the GNU Public
-- License.  Full text of the license is available from the GNU Project:
-- http://www.fsf.org/copyleft/gpl.html

-- Drop all data in workflow tables by dropping the acs objects of all workflows in the system.
-- This is sufficient since all workflow data ultimately
-- hangs on workflow instances and will be dropped on cascade
create function inline_0 ()
returns integer as '
declare
        row     record;
begin
        for row in select object_id from acs_objects
                          where object_type = ''workflow_lite''
        loop
                perform acs_object__delete(row.object_id);
        end loop;

        return 1;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0();

-- Drop the workflow object type
create function inline_0 ()
returns integer as '
begin
        perform acs_object_type__drop_type(''workflow_lite'', ''t'');

        return 1;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0();

-- Drop all tables
drop table workflow_case_fsm;
drop table workflow_case_role_party_map;
drop table workflow_case_log_data;
drop table workflow_case_log;
drop table workflow_cases;
drop table workflow_fsm_action_enabled_in_states;
drop table workflow_fsm_actions;
drop table workflow_initial_action;
drop table workflow_fsm_states;
drop table workflow_action_callbacks;
drop table workflow_action_privileges;
drop table workflow_action_allowed_roles;
drop table workflow_actions;
drop table workflow_role_callbacks;
drop table workflow_role_allowed_parties;
drop table workflow_role_default_parties;
drop table workflow_roles;
drop table workflow_callbacks;
drop table workflows;

-- Drop sequences
drop sequence workflow_roles_seq;
drop sequence workflow_actions_seq;
drop sequence workflow_fsm_states_seq;
drop sequence workflow_cases_seq;
drop sequence workflow_case_log_seq;
