-- Data model for the workflow package, part of the OpenACS system.
--
-- @author Lars Pind (lars@collaboraid.biz)
-- @author Peter Marklund (peter@collaboraid.biz)
--
-- @creation-date 9 January 2003
--
-- This is free software distributed under the terms of the GNU Public
-- License.  Full text of the license is available from the GNU Project:
-- http://www.fsf.org/copyleft/gpl.html

---------------------------------
-- Workflow level, Generic Model
---------------------------------

-- Create the workflow object type
-- We use workflow_new rather than just workflow
-- to avoid a clash with the old workflow package acs-workflow
create function inline_0 ()
returns integer as '
begin
    PERFORM acs_object_type__create_type (
	''workflow_new'',
	''New Workflow'',
	''New Workflows'',
	''acs_object'',
	''workflows'',
	''workflow_id'',
	null,
	''f'',
	null,
	null
	);

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();

create table workflows (
  workflow_id             integer
                          constraint workflows_pk
                          primary key
                          constraint workflows_workflow_id_fk
                          references acs_objects(object_id)
                          on delete cascade,
  short_name              varchar(100)
                          constraint workflows_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint workflows_pretty_name_nn
                          not null,
  object_id               integer
                          constraint workflows_object_id_nn
                          not null
                          constraint workflows_object_id_fk
                          references acs_objects(object_id)
                          on delete cascade,
  -- object_id points to either a package type, package instance, or single workflow case
  -- For Bug Tracker, every package instance will get its own workflow instance that is a copy
  -- of the workflow instance for the Bug Tracker package type
  object_type             varchar(1000)
                          constraint workflows_object_type_nn
                          not null
                          constraint workflows_object_type_fk
                          references acs_object_types(object_type)
                          on delete cascade,
  -- the object type (and its subtypes) this workflow is designed for. Use acs_object
  -- if you don't want to restrict the types of objects this workflow can be applied to.
  constraint workflows_oid_sn_un
  unique (object_id, short_name)
);

-- For callback procedures that execute when any action in the workflow is taken
create table workflow_side_effects (
  workflow_id             integer
                          constraint workflow_side_effects_wid_nn
                          not null
                          constraint workflow_side_effects_wid_fk
                          references workflows(workflow_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint workflow_side_effects_sci_nn
                          not null
                          constraint workflow_side_effects_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer
                          constraint workflow_side_effects_so_nn
                          not null,
  constraint workflow_side_effects_pk
  primary key (workflow_id, acs_sc_impl_id)
);

create table workflow_roles (
  role_id                 integer
                          constraint workflow_roles_pk
                          primary key,
  workflow_id             integer
                          constraint workflow_roles_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  short_name              varchar(100)
                          constraint workflow_roles_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint workflow_roles_pretty_name_nn
                          not null
);

create sequence t_wf_workflow_roles_seq;
create view wf_workflow_roles_seq as
select nextval('t_wf_workflow_roles_seq') as nextval;

-- Static role-party map
create table workflow_role_default_parties (
  role_id                 integer
                          constraint workflow_role_default_parties_rid_nn
                          not null
                          constraint workflow_role_default_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint workflow_role_default_parties_pid_nn
                          not null
                          constraint workflow_role_default_parties_pid_fk
                          references parties(party_id)
                          on delete cascade,
  constraint workflow_role_default_parties_pk
  primary key (role_id, party_id)
);

-- Static map between roles and parties allowed to be in those roles
create table workflow_role_allowed_parties (
  role_id                 integer
                          constraint workflow_role_allowed_parties_rid_nn
                          not null
                          constraint workflow_role_allowed_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint workflow_role_allowed_parties_pid_nn
                          not null
                          constraint workflow_role_allowed_parties_pid_fk
                          references parties(party_id)
                          on delete cascade,
  constraint workflow_role_allowed_parties_pk
  primary key (role_id, party_id)
);

-- Application specific callback procedures for dynamically mapping parties to roles
create table workflow_role_assignment_rules (
  role_id                 integer
                          constraint workflow_role_assignment_rules_role_id_nn
                          not null
                          constraint workflow_role_assignment_rules_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint workflow_role_assignment_rules_contract_id_nn
                          not null
                          constraint workflow_role_assignment_rules_contract_id_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  -- this can be an implementation of any of the three assignment
  -- service contracts: DefaultAssignee, AssigneePickList, or 
  -- AssigneeSubQuery
  sort_order              integer
                          constraint workflow_role_assignment_rules_sort_order_nn
                          not null,
  constraint workflow_role_assignment_rules_pk
  primary key (role_id, acs_sc_impl_id)
);

create table workflow_actions (
  action_id               integer
                          constraint workflow_actions_pk
                          primary key,
  workflow_id             integer
                          constraint workflow_actions_workflow_id_nn
                          not null
                          constraint workflow_actions_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer
                          constraint workflow_actions_sort_order_nn
                          not null,
  short_name              varchar(100)
                          constraint workflow_actions_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint workflow_actions_pretty_name_nn
                          not null,
  pretty_past_tense       varchar(200),
  assigned_role           integer
                          constraint workflow_actions_assigned_role_fk
                          references workflow_roles(role_id)
                          on delete set null
);

create sequence t_wf_workflow_actions_seq;
create view wf_workflow_actions_seq as
select nextval('t_wf_workflow_actions_seq') as nextval;

-- Determines which roles are allowed to take certain actions
create table workflow_action_allowed_roles (
  action_id               integer
                          constraint workflow_action_allowed_roles_action_id_nn
                          not null
                          constraint workflow_action_allowed_roles_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  role_id                 integer
                          constraint workflow_action_allowed_roles_role_id_nn
                          not null
                          constraint workflow_action_allowed_roles_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  constraint workflow_action_allowed_roles_pk
  primary key (action_id, role_id)
);

-- Determines which privileges (on the object treated by a workflow case) will allow
-- users to take certain actions
create table workflow_action_privileges (
  action_id               integer
                          constraint workflow_action_privileges_action_id_nn
                          not null
                          constraint workflow_action_privileges_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  privilege               varchar(100)
                          constraint workflow_action_privileges_privilege_nn
                          not null
                          constraint workflow_action_privileges_privilege_fk
                          references acs_privileges(privilege)
                          on delete cascade,
  constraint workflow_action_privileges_pk
  primary key (action_id, privilege)
);

-- For application specific callback procedures that execute when
-- certain actions are taken
create table workflow_action_side_effects (
  action_id               integer
                          constraint workflow_action_side_effects_action_id_nn
                          not null
                          constraint workflow_action_side_effects_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint workflow_action_side_effects_sci_nn
                          not null
                          constraint workflow_action_side_effects_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer
                          constraint workflow_action_side_effects_sort_order_nn
                          not null,
  constraint workflow_action_side_effects_pk
  primary key (action_id, acs_sc_impl_id)
);

---------------------------------
-- Workflow level, Finite State Machine Model
---------------------------------

create table workflow_fsm_states (
  state_id                integer
                          constraint workflow_fsm_states_pk
                          primary key,
  workflow_id             integer
                          constraint workflow_fsm_states_workflow_id_nn
                          not null
                          constraint workflow_fsm_states_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer
                          constraint workflow_fsm_states_sort_order_nn
                          not null,
  short_name              varchar(100)
                          constraint workflow_fsm_states_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint workflow_fsm_states_pretty_name_nn
                          not null
);

create sequence t_wf_workflow_fsm_states_seq;
create view wf_workflow_fsm_states_seq as
select nextval('t_wf_workflow_fsm_states_seq') as nextval;

create table workflow_fsm_actions (
  action_id               integer
                          constraint workflow_fsm_actions_pk
                          primary key
                          constraint workflow_fsm_actions_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  new_state               integer
                          constraint workflow_fsm_actions_new_state_fk
                          references workflow_fsm_states(state_id)
                          on delete set null
  -- can be null
);

create table workflow_fsm_action_enabled_in_states (
  action_id               integer
                          constraint workflow_fsm_action_enabled_in_states_action_id_nn
                          not null
                          constraint workflow_fsm_action_enabled_in_states_action_id_fk
                          references workflow_fsm_actions(action_id)
                          on delete cascade,
  state_id                integer
                          constraint workflow_fsm_action_enabled_in_states_state_id_nn
                          not null
                          constraint workflow_fsm_action_enabled_in_states_state_id_fk
                          references workflow_fsm_states
                          on delete cascade
);

create table workflow_fsm (
  workflow_id             integer
                          constraint workflow_fsm_pk
                          primary key
                          constraint workflow_fsm_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  initial_state           integer
                          constraint workflow_fsm_initial_state_nn
                          not null
                          constraint workflow_fsm_initial_state_fk
                          references workflow_fsm_states(state_id)
);

---------------------------------
-- Case level, Generic Model
---------------------------------

create table workflow_cases (
  case_id                 integer
                          constraint workflow_cases_pk
                          primary key
                          constraint workflow_cases_case_id_fk
                          references acs_objects(object_id)
                          on delete cascade,
  workflow_id             integer
                          constraint workflow_cases_workflow_id_nn
                          not null
                          constraint workflow_cases_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  object_id               integer
                          constraint workflow_cases_object_id_nn
                          not null
                          constraint workflow_cases_object_id_fk
                          references acs_objects(object_id)
                          on delete cascade
                          constraint workflow_cases_object_id_un
                          unique
  -- the object which this case is about, e.g. the acs-object for a bug-tracker bug
);

create table workflow_case_log (
  entry_id                integer
                          constraint workflow_case_log_pk
                          primary key,
  case_id                 integer
                          constraint workflow_case_log_case_id_fk 
                          references workflow_cases(case_id)
                          on delete cascade,
  action_id               integer
                          constraint workflow_case_log_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  user_id                 integer
                          constraint workflow_case_log_user_id_fk
                          references users(user_id)
                          on delete cascade,
  action_date             timestamp
                          constraint workflow_case_log_action_date_nn
                          not null 
                          default now(),
  comment                 text,
  comment_format          varchar(30) default 'plain' not null
                          constraint  bt_bug_actions_comment_format_ck
                          check (comment_format in ('html', 'plain', 'pre'))
);

create table workflow_case_log_data (
  entry_id                integer
                          constraint workflow_case_log_data_eid_nn
                          not null
                          constraint workflow_case_log_data_eid_fk
                          references workflow_case_log(entry_id)
                          on delete cascade,
  key                     varchar(50),
  value                   varchar(4000),
  constraint workflow_case_log_data_pk
  primary key (entry_id, key)
);

create table workflow_case_role_party_map (
  case_id                 integer
                          constraint workflow_case_role_party_map_case_id_nn
                          not null
                          constraint workflow_case_role_party_map_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  role_id                 integer
                          constraint workflow_case_role_party_map_case_id_nn
                          not null
                          constraint workflow_case_role_party_map_case_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint workflow_case_role_party_map_party_id_nn
                          not null
                          constraint workflow_case_role_party_map_party_id_fk
                          references parties(party_id)
                          on delete cascade,
  constraint workflow_case_role_party_map_pk
  primary key (case_id, role_id, party_id)
);

---------------------------------
-- Case level, Finite State Machine Model
---------------------------------

create table workflow_case_fsm (
  case_id                 integer
                          constraint workflow_case_fsm_case_id_nn
                          not null
                          constraint workflow_case_fsm_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  current_state           integer
                          constraint workflow_case_fsm_state_id_nn
                          not null
                          constraint workflow_case_fsm_state_id_fk
                          references workflow_fsm_states(state_id)
                          on delete cascade
);
