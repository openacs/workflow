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
begin
  acs_object_type.create_type (
    object_type => 'workflow_lite',
    pretty_name => 'Workflow Lite',
    pretty_plural => 'Workflow Lites',
    supertype => 'acs_object',
    table_name => 'workflows',
    id_column => 'workflow_id',
    package_name => null,
    abstract_p => 'f',
    type_extension_table => null,
    name_method => null
  );
end;
/
show errors

-- A generic table for any kind of workflow implementation
-- Currently, the table only holds FSM workflows but when 
-- other types of workflows are added we will add a table
-- to hold workflow_types and reference that table from
-- this workflows table.
create table workflows (
  workflow_id             constraint wfs_pk
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
  object_id               constraint wfs_object_id_fk
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
  description             clob,
  description_mime_type   varchar2(200) default 'text/plain',
  constraint wfs_oid_sn_un
  unique (package_key, object_id, short_name)
);

-- For callbacks on workflow
create table workflow_callbacks (
  workflow_id             constraint wf_cbks_wid_nn
                          not null
                          constraint wf_cbks_wid_fk
                          references workflows(workflow_id)
                          on delete cascade,
  acs_sc_impl_id          constraint wf_cbks_sci_nn
                          not null
                          constraint wf_cbks_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer constraint wf_cbks_so_nn
                          not null,
  constraint wf_cbks_pk
  primary key (workflow_id, acs_sc_impl_id)
);

create table workflow_roles (
  role_id                 integer constraint wf_roles_pk
                          primary key,
  workflow_id             constraint wf_roles_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  short_name              varchar(100)
                          constraint wf_roles_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_roles_pretty_name_nn
                          not null,
  sort_order              integer constraint wf_roles_so_nn
                          not null,
  constraint wf_roles_short_name_un
  unique (workflow_id, short_name),
  constraint wf_roles_pretty_name_un
  unique (workflow_id, pretty_name)
);

create sequence workflow_roles_seq;

-- Callbacks for roles
create table workflow_role_callbacks (
  role_id                 integer constraint wf_role_cbks_role_id_nn
                          not null
                          constraint wf_role_cbks_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  acs_sc_impl_id          constraint wf_role_cbks_contract_id_nn
                          not null
                          constraint wf_role_cbks_contract_id_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  -- this should be an implementation of any of the three assignment
  -- service contracts: DefaultAssignee, AssigneePickList, or 
  -- AssigneeSubQuery
  sort_order              integer constraint wf_role_cbks_sort_order_nn
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
  workflow_id             constraint wf_acns_workflow_id_nn
                          not null
                          constraint wf_acns_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer constraint wf_acns_sort_order_nn
                          not null,
  short_name              varchar(100)
                          constraint wf_acns_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_acns_pretty_name_nn
                          not null,
  pretty_past_tense       varchar(200),
  description             clob,
  description_mime_type   varchar2(200) default 'text/plain',
  edit_fields             varchar(4000),
  assigned_role           constraint wf_acns_assigned_role_fk
                          references workflow_roles(role_id)
                          on delete set null,
  always_enabled_p        char(1) default 'f'
                          constraint wf_acns_enabled_p_ck
                          check (always_enabled_p in ('t','f')),
 -- When the action to automatically fire.
 -- A value of 0 means immediately, null means never.
 -- Other values mean x amount of time after having become enabled
 timeout_seconds          integer,
  constraint wf_actions_short_name_un
  unique (workflow_id, short_name),
  constraint wf_actions_pretty_name_un
  unique (workflow_id, pretty_name)
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
  role_id                 integer constraint wf_acn_alwd_roles_role_id_nn
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
  acs_sc_impl_id          constraint wf_acn_cbks_sci_nn
                          not null
                          constraint wf_acn_cbks_sci_fk
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  sort_order              integer constraint wf_acn_cbks_sort_order_nn
                          not null,
  constraint wf_acn_cbks_pk
  primary key (action_id, acs_sc_impl_id)
);

-- For the initial action, which fires when a new case is started
create table workflow_initial_action (
  workflow_id             constraint wf_initial_acn_pk
                          primary key
                          constraint wf_initial_acn_wf_fk
                          references workflows(workflow_id)
                          on delete cascade,
  action_id               constraint wf_initial_acn_act_fk
                          references workflow_actions(action_id)
                          on delete cascade
);

-- TODO: Test these
create table workflow_action_children(
  child_id                  integer
                            constraint wf_action_children_pk
                            primary key,
  action_id                 integer
                            constraint wf_action_children_nn
                            not null
                            constraint wf_action_children_action_fk
                            references workflow_actions(action_id)
                            on delete cascade,
  child_workflow            integer
                            constraint wf_action_children_workflow_fk
                            references workflows(workflow_id)
                            on delete cascade
);

create table workflow_action_child_role_map(
  child_id                  integer
                            constraint wf_act_child_rl_map_child_fk
                            references workflow_action_children(child_id),
  parent_role               integer
                            constraint wf_act_child_rl_map_prnt_rl_fk
                            references workflow_roles(role_id),
  child_role                integer
                            constraint wf_act_child_rl_map_chld_rl_fk
                            references workflow_roles(role_id),
  mapping_type              char(40)
                            constraint wf_act_child_rl_map_type_ck
                            check (mapping_type in 
                                ('per_role','per_user')),
  constraint wf_act_chld_rl_map_pk
  primary key (child_id, parent_role)
);

comment on column workflow_action_child_role_map.mapping_type is '
  If per user, we create a child workflow per user who is a member of any of the parties assigned to the parent_role.
  If per role, we create just one child workflow, with the exact same parties that are in the parent_role.
  If more than one child_role has a mapping_type other than per_role, the cartesian product of these roles will be created.
';

---------------------------------
-- Workflow level, Finite State Machine Model
---------------------------------

create table workflow_fsm_states (
  state_id                integer
			  constraint wf_fsm_states_pk
                          primary key,
  workflow_id             constraint wf_fsm_states_workflow_id_nn
                          not null
                          constraint wf_fsm_states_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  sort_order              integer constraint wf_fsm_states_sort_order_nn
                          not null,
  -- The state with the lowest sort order is the initial state
  short_name              varchar(100)
                          constraint wf_fsm_states_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_fsm_states_pretty_name_nn
                          not null,
  hide_fields             varchar(4000),
  constraint wf_fsm_states_short_name_un
  unique (workflow_id, short_name),
  constraint wf_fsm_states_pretty_name_un
  unique (workflow_id, pretty_name)

);

create sequence workflow_fsm_states_seq;

create table workflow_fsm_actions (
  action_id               integer
			  constraint wf_fsm_acns_aid_fk
                          references workflow_actions(action_id)
                          on delete cascade
                          constraint wf_fsm_acns_pk
                          primary key,
  new_state               constraint wf_fsm_acns_new_st_fk
                          references workflow_fsm_states(state_id)
                          on delete cascade
  -- can be null
);

-- If an action is enabled in all states it won't have any entries in this table
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
                          on delete cascade,
  assigned_p              char(1) default 'f'
                          constraint wf_fsm_acns_enabled_p_ck
                          check (assigned_p in ('t','f'))
  -- The users in the role assigned to an action are only assigned to take action
  -- in the enabled states that have the assigned_p flag
  -- set to true. For example, in Bug Tracker, the resolve action is enabled
  -- in both the open and resolved states but only has assigned_p set to true
  -- in the open state.
);



--------------------------------------------------------
-- Workflow level, context-dependent (assignments, etc.)
--------------------------------------------------------


-- Static role-party map
create table workflow_role_default_parties (
  role_id                 integer constraint wf_role_default_parties_rid_nn
                          not null
                          constraint wf_role_default_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                constraint wf_role_default_parties_pid_nn
                          not null
                          constraint wf_role_default_parties_pid_fk
                          references parties(party_id)
                          on delete cascade,
  constraint wf_role_default_parties_pk
  primary key (role_id, party_id)
);

-- Static map between roles and parties allowed to be in those roles
create table workflow_role_allowed_parties (
  role_id                 integer constraint wf_role_alwd_parties_rid_nn
                          not null
                          constraint wf_role_alwd_parties_rid_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                constraint wf_role_alwd_parties_pid_nn
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
			  constraint workflow_cases_pk
                          primary key,
  workflow_id             constraint wf_cases_workflow_id_nn
                          not null
                          constraint wf_cases_workflow_id_fk
                          references workflows(workflow_id)
                          on delete cascade,
  object_id               constraint wf_cases_object_id_nn
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
			  constraint wf_cs_role_pty_map_case_id_nn
                          not null
                          constraint wf_cs_role_pty_map_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  role_id                 integer constraint wf_cs_role_pty_map_role_id_nn
                          not null
                          constraint wf_cs_role_pty_map_role_id_fk
                          references workflow_roles(role_id)
                          on delete cascade,
  party_id                constraint wf_cs_role_pty_map_pty_id_nn
                          not null
                          constraint wf_cs_role_pty_map_pty_id_fk
                          references parties(party_id)
                          on delete cascade,
  constraint wf_case_role_pty_map_pk
  primary key (case_id, role_id, party_id)
);

create sequence workflow_case_enbl_act_seq;

create table workflow_case_enabled_actions(
  enabled_action_id       integer
                          constraint wf_case_enbl_act_case_id_pk
                          primary key,
  case_id                 integer
                          constraint wf_case_enbl_act_case_id_nn
                          not null
                          constraint wf_case_enbl_act_case_id_fk
                          references workflow_cases(case_id)
                          on delete cascade,
  action_id               integer
                          constraint wf_case_enbl_act_action_id_nn
                          not null
                          constraint wf_case_enbl_act_action_id_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  enabled_date            date
                          default sysdate,
  executed_date           date,
  enabled_state           char(40)
                          constraint wf_case_enbl_act_state_ck
                          check (enabled_state in ('enabled','completed','canceled','refused')),
  -- the timestamp when this action will fire
  execution_time          date
);

create index wf_case_enbl_act_case_idx on workflow_case_enabled_actions(case_id);
create index wf_case_enbl_act_action_idx on workflow_case_enabled_actions(action_id);
create index wf_case_enbl_act_state_idx on workflow_case_enabled_actions(enabled_state);

---------------------------------
-- Deputies
---------------------------------

-- When a user is away, for example on vacation, he
-- can hand over his workflow roles to some other user - a deputy
create table workflow_deputies (
  user_id             integer
		      constraint workflow_deputies_pk
		      primary key
		      constraint workflow_deputies_uid_fk
		      references users(user_id),
  deputy_user_id      integer
		      constraint workflow_deputies_duid_fk
		      references users(user_id),
  start_date	      date
		      constraint workflow_deputies_sdate_nn
		      not null,
  end_date	      date
		      constraint workflow_deputies_edate_nn
		      not null,
  message	      varchar(4000)
);

-- role-to-user-map with deputies. Does not select users who
-- have deputies, should we do that?
create or replace view workflow_case_role_user_map as
select distinct q.case_id,
       q.role_id,
       q.user_id,
       q.on_behalf_of_user_id
from (
    select rpm.case_id,
           rpm.role_id,
           pmm.member_id as user_id,
           pmm.member_id as on_behalf_of_user_id
    from   workflow_case_role_party_map rpm, 
           party_approved_member_map pmm,
	   users u
    where  rpm.party_id = pmm.party_id
    and    pmm.member_id = u.user_id
    and    not exists (select 1 
                       from workflow_deputies 
                       where user_id = pmm.member_id
                       and sysdate between start_date and end_date)
    union
    select rpm.case_id,
           rpm.role_id,
           dep.deputy_user_id as user_id,
           pmm.member_id as on_behalf_of_user_id
    from   workflow_case_role_party_map rpm, 
           party_approved_member_map pmm,
	   users u,
           workflow_deputies dep
    where  rpm.party_id = pmm.party_id
    and    pmm.member_id = u.user_id
    and    dep.user_id = pmm.member_id
    and    sysdate between dep.start_date and dep.end_date
) q;

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
  current_state           constraint wf_case_fsm_st_id_fk
                          references workflow_fsm_states(state_id)
                          on delete cascade
);


---------------------------------
-- Case level, Activity Log
---------------------------------

--begin;
--    select content_type__create_type (
--        'workflow_activity_log', -- content_type
--	'content_revision',      -- supertype
--	'Workflow Activity Log', -- pretty_name
--	'Workflow Activity Log', -- pretty_plural
--	'workflow_case_log',     -- table_name
--	'entry_id'              -- id_column
--    );
--end;


create sequence workflow_case_log_seq;

create table workflow_case_log (
  entry_id                integer
		 	  constraint wf_case_log_pk
                          primary key,
  case_id                 integer
			  constraint wf_case_log_case_id_fk 
                          references workflow_cases(case_id)
                          on delete cascade,
  action_id               integer 
			  constraint wf_case_log_acn_id_fk
                          references workflow_actions(action_id)
                          on delete cascade
);

create index workflow_case_log_action_id on workflow_case_log (action_id);
create index workflow_case_log_case_id on workflow_case_log (case_id);


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

begin
    content_type.create_type (
        content_type => 'workflow_case_log_entry',
        supertype => 'content_revision',
        pretty_name => 'Workflow Case Log Entry',
        pretty_plural => 'Workflow Case Log Entries',
        table_name => 'workflow_case_log_rev',
        id_column => 'entry_rev_id',
        name_method => null
    );
end;
/
show errors

-----------------
-- Useful views
-----------------

create or replace view workflow_case_assigned_actions as 
    select c.workflow_id,
           c.case_id, 
           c.object_id,
           a.action_id, 
           a.assigned_role as role_id
    from   workflow_cases c,
           workflow_case_fsm cfsm,
           workflow_actions a,
           workflow_fsm_action_en_in_st aeis
    where  cfsm.case_id = c.case_id
    and    a.always_enabled_p = 'f'
    and    aeis.state_id = cfsm.current_state
    and    aeis.assigned_p = 't'
    and    a.action_id = aeis.action_id
    and    a.assigned_role is not null;
