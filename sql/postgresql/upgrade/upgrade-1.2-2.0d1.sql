--
-- Adds timed actions
-- 
-- @cvs-id $Id$
--


alter table workflow_actions add timeout interval;


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
  enabled_date            timestamptz 
                          default current_timestamp,
  executed_date           timestamptz,
  enabled_state           char(40)
                          constraint wf_case_enbl_act_state_ck
                          check (enabled_state in ('enabled','completed','canceled','refused')),
  -- the timestamp when this action will fire
  execution_time          timestamptz
);

create index wf_case_enbl_act_case_idx on workflow_case_enabled_actions(case_id);
create index wf_case_enbl_act_action_idx on workflow_case_enabled_actions(action_id);
create index wf_case_enbl_act_state_idx on workflow_case_enabled_actions(enabled_state);


-- Missing unique constraints on names
-- TODO: Test these
alter table workflow_roles add constraint wf_roles_short_name_un unique (workflow_id, short_name);
alter table workflow_roles add constraint wf_roles_pretty_name_un unique (workflow_id, pretty_name);

alter table workflow_actions add constraint wf_actions_short_name_un unique (workflow_id, short_name);
alter table workflow_actions add constraint wf_actions_pretty_name_un unique (workflow_id, pretty_name);

alter table workflow_fsm_states add constraint wf_fsm_states_short_name_un unique (workflow_id, short_name);
alter table workflow_fsm_states add constraint wf_fsm_states_pretty_name_un unique (workflow_id, pretty_name);


-- New not null constraints
alter table workflow_initial_action alter column workflow_id set not null;
alter table workflow_roles alter column workflow_id set not null;


-- Changing from 'on delete cascade' to 'on delete set null'
alter table workflow_fsm_actions drop constraint wf_fsm_acns_new_st_fk;
alter table workflow_fsm_actions add 
    constraint wf_fsm_acns_new_st_fk foreign key (new_state)
    references workflow_fsm_states(state_id) on delete set null;


-- Adding recursive actions
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
