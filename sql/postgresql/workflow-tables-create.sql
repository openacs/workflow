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
-- We use workflow_lite rather than just workflow
-- to avoid a clash with the old workflow package acs-workflow
create function inline_0 ()
returns integer as '
begin
    PERFORM acs_object_type__create_type (
	''workflow_lite'',
	''Workflow Lite'',
	''Workflow Lites'',
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

-- A generic table for any kind of workflow implementation
-- Currently, the table only holds FSM workflows but when 
-- other types of workflows are added we will add a table
-- to hold workflow_types and reference that table from
-- this workflows table.
create table workflows (
  workflow_id             integer
                          constraint wfs_pk
                          primary key
                          constraint wfs_workflow_id_fk
                          references acs_objects(object_id)
                          on delete cascade,
  short_name              varchar(100)
                          constraint wfs_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wfs_pretty_name_nn
                          not null,
  object_id               integer
                          constraint wfs_object_id_fk
                          references acs_objects(object_id)
                          on delete cascade,
  package_key             varchar(100)
                          constraint wfs_package_key_nn
                          not null
                          constraint wfs_apm_package_types_fk
                          references apm_package_types(package_key),
  -- object_id points to either a package type, package instance, or single workflow case
  -- For Bug Tracker, every package instance will get its own workflow instance that is a copy
  -- of the workflow instance for the Bug Tracker package type
  object_type             varchar(1000)
                          constraint wfs_object_type_nn
                          not null
                          constraint wfs_object_type_fk
                          references acs_object_types(object_type)
                          on delete cascade,
  constraint wfs_oid_sn_un
  unique (package_key, object_id, short_name)
);

-- For callbacks on workflow
create table workflow_callbacks (
  workflow_id             integer
                          constraint wf_cbks_wid_nn
                          not null
                          constraint wf_cbks_wid_fk
                          references workflows(workflow_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint wf_cbks_sci_nn
                          not null
                          constraint wf_cbks_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer
                          constraint wf_cbks_so_nn
                          not null,
  constraint wf_cbks_pk
  primary key (workflow_id, acs_sc_impl_id)
);

create table workflow_roles (
  role_id                 integer
                          constraint wf_roles_pk
                          primary key,
  workflow_id             integer
                          constraint wf_roles_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  short_name              varchar(100)
                          constraint wf_roles_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_roles_pretty_name_nn
                          not null,
  sort_order              integer
                          constraint wf_roles_so_nn
                          not null
);

create sequence workflow_roles_seq;

-- Callbacks for roles
create table workflow_role_callbacks (
  role_id                 integer
                          constraint wf_role_cbks_role_id_nn
                          not null
                          constraint wf_role_cbks_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint wf_role_cbks_contract_id_nn
                          not null
                          constraint wf_role_cbks_contract_id_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  -- this should be an implementation of any of the three assignment
  -- service contracts: DefaultAssignee, AssigneePickList, or 
  -- AssigneeSubQuery
  sort_order              integer
                          constraint wf_role_cbks_sort_order_nn
                          not null,
  constraint wf_role_cbks_pk
  primary key (role_id, acs_sc_impl_id),
  constraint wf_role_asgn_rol_sort_un
  unique (role_id, sort_order)
);

create table workflow_actions (
  action_id               integer
                          constraint wf_acns_pk
                          primary key,
  workflow_id             integer
                          constraint wf_acns_workflow_id_nn
                          not null
                          constraint wf_acns_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer
                          constraint wf_acns_sort_order_nn
                          not null,
  short_name              varchar(100)
                          constraint wf_acns_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_acns_pretty_name_nn
                          not null,
  pretty_past_tense       varchar(200),
  edit_fields             varchar(4000),
  assigned_role           integer
                          constraint wf_acns_assigned_role_fk
                          references workflow_roles(role_id)
                          on delete set null,
  always_enabled_p        bool default 'f'
);

create sequence workflow_actions_seq;

-- Determines which roles are allowed to take certain actions
create table workflow_action_allowed_roles (
  action_id               integer
                          constraint wf_acn_alwd_roles_acn_id_nn
                          not null
                          constraint wf_acn_alwd_roles_acn_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  role_id                 integer
                          constraint wf_acn_alwd_roles_role_id_nn
                          not null
                          constraint wf_acn_alwd_roles_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  constraint wf_acn_alwd_roles_pk
  primary key (action_id, role_id)
);

-- Determines which privileges (on the object treated by a workflow case) will allow
-- users to take certain actions
create table workflow_action_privileges (
  action_id               integer
                          constraint wf_acn_priv_acn_id_nn
                          not null
                          constraint wf_acn_priv_acn_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  privilege               varchar(100)
                          constraint wf_acn_priv_privilege_nn
                          not null
                          constraint wf_acn_priv_privilege_fk
                          references acs_privileges(privilege)
                          on delete cascade,
  constraint wf_acn_priv_pk
  primary key (action_id, privilege)
);

-- For callbacks on actions
create table workflow_action_callbacks (
  action_id               integer
                          constraint wf_acn_cbks_acn_id_nn
                          not null
                          constraint wf_acn_cbks_acn_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          constraint wf_acn_cbks_sci_nn
                          not null
                          constraint wf_acn_cbks_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer
                          constraint wf_acn_cbks_sort_order_nn
                          not null,
  constraint wf_acn_cbks_pk
  primary key (action_id, acs_sc_impl_id)
);

-- For the initial action, which fires when a new case is started
create table workflow_initial_action (
  workflow_id             integer
                          constraint wf_initial_acn_pk
                          primary key
                          constraint wf_initial_acn_wf_fk
                          references workflows(workflow_id)
                          on delete cascade,
  action_id               integer
                          constraint wf_initial_acn_act_fk
                          references workflow_actions(action_id)
                          on delete cascade
);


---------------------------------
-- Workflow level, Finite State Machine Model
---------------------------------

create table workflow_fsm_states (
  state_id                integer
                          constraint wf_fsm_states_pk
                          primary key,
  workflow_id             integer
                          constraint wf_fsm_states_workflow_id_nn
                          not null
                          constraint wf_fsm_states_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer
                          constraint wf_fsm_states_sort_order_nn
                          not null,
  -- The state with the lowest sort order is the initial state
  short_name              varchar(100)
                          constraint wf_fsm_states_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_fsm_states_pretty_name_nn
                          not null,
  hide_fields             varchar(4000)
);

create sequence workflow_fsm_states_seq;

create table workflow_fsm_actions (
  action_id               integer
                          constraint wf_fsm_acns_aid_fk
                          references workflow_actions(action_id)
                          on delete cascade
                          constraint wf_fsm_acns_pk
                          primary key,
  new_state               integer
                          constraint wf_fsm_acns_new_st_fk
                          references workflow_fsm_states(state_id)
                          on delete cascade
  -- can be null
);

-- If an action is enabled in all states it won't have any entries in this table
-- it is enabled in all states
create table workflow_fsm_action_en_in_st (
  action_id               integer
                          constraint wf_fsm_acn_enb_in_st_acn_id_nn
                          not null
                          constraint wf_fsm_acn_enb_in_st_acn_id_fk
                          references workflow_fsm_actions(action_id)
                          on delete cascade,
  state_id                integer
                          constraint wf_fsm_acn_enb_in_st_st_id_nn
                          not null
                          constraint wf_fsm_acn_enb_in_st_st_id_fk
                          references workflow_fsm_states
                          on delete cascade
);



--------------------------------------------------------
-- Workflow level, context-dependent (assignments, etc.)
--------------------------------------------------------


-- Static role-party map
create table workflow_role_default_parties (
  role_id                 integer
                          constraint wf_role_default_parties_rid_nn
                          not null
                          constraint wf_role_default_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint wf_role_default_parties_pid_nn
                          not null
                          constraint wf_role_default_parties_pid_fk
                          references parties(party_id)
                          on delete cascade,
  constraint wf_role_default_parties_pk
  primary key (role_id, party_id)
);

-- Static map between roles and parties allowed to be in those roles
create table workflow_role_allowed_parties (
  role_id                 integer
                          constraint wf_role_alwd_parties_rid_nn
                          not null
                          constraint wf_role_alwd_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint wf_role_alwd_parties_pid_nn
                          not null
                          constraint wf_role_alwd_parties_pid_fk
                          references parties(party_id)
                          on delete cascade,
  constraint wf_role_alwd_parties_pk
  primary key (role_id, party_id)
);




---------------------------------
-- Case level, Generic Model
---------------------------------

create sequence workflow_cases_seq;

create table workflow_cases (
  case_id                 integer
                          constraint wf_cases_pk
                          primary key,
  workflow_id             integer
                          constraint wf_cases_workflow_id_nn
                          not null
                          constraint wf_cases_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  object_id               integer
                          constraint wf_cases_object_id_nn
                          not null
                          constraint wf_cases_object_id_fk
                          references acs_objects(object_id)
                          on delete cascade
                          constraint wf_cases_object_id_un
                          unique
  -- the object which this case is about, e.g. the acs-object for a bug-tracker bug
);

create table workflow_case_role_party_map (
  case_id                 integer
                          constraint wf_case_role_pty_map_case_id_nn
                          not null
                          constraint wf_case_role_pty_map_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  role_id                 integer
                          constraint wf_case_role_pty_map_case_id_nn
                          not null
                          constraint wf_case_role_pty_map_case_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                integer
                          constraint wf_case_role_pty_map_pty_id_nn
                          not null
                          constraint wf_case_role_pty_map_pty_id_fk
                          references parties(party_id)
                          on delete cascade,
  constraint wf_case_role_pty_map_pk
  primary key (case_id, role_id, party_id)
);

---------------------------------
-- Case level, Finite State Machine Model
---------------------------------

create table workflow_case_fsm (
  case_id                 integer
                          constraint wf_case_fsm_case_id_nn
                          not null
                          constraint wf_case_fsm_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  current_state           integer
                          constraint wf_case_fsm_st_id_fk
                          references workflow_fsm_states(state_id)
                          on delete cascade
);


---------------------------------
-- Case level, Activity Log
---------------------------------

begin;
    select content_type__create_type (
        'workflow_activity_log', -- content_type
	'content_revision',      -- supertype
	'Workflow Activity Log', -- pretty_name
	'Workflow Activity Log', -- pretty_plural
	'workflow_case_log',     -- table_name
	'entry_id',              -- id_column
    );
end;


create sequence workflow_case_log_seq;

create table workflow_case_log (
  entry_id                integer
                          constraint wf_case_log_eid_fk
                          references cr_revisions on delete cascade
                          constraint wf_case_log_pk
                          primary key,
  case_id                 integer
                          constraint wf_case_log_case_id_fk 
                          references workflow_cases(case_id)
                          on delete cascade,
  action_id               integer
                          constraint wf_case_log_acn_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  comment_format          varchar(50) 
                          default 'text/plain'
                          constraint wf_clog_comment_format_nn
                          not null
);

create table workflow_case_log_data (
  entry_id                integer
                          constraint wf_case_log_data_eid_nn
                          not null
                          constraint wf_case_log_data_eid_fk
                          references workflow_case_log(entry_id)
                          on delete cascade,
  key                     varchar(50),
  value                   varchar(4000),
  constraint wf_case_log_data_pk
  primary key (entry_id, key)
);

