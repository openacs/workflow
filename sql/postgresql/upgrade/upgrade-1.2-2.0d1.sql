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
alter table workflow_actions add
  child_workflow_id       integer
                          constraint wf_acns_child_workflow_fk
                          references workflows(workflow_id)
                          on delete cascade;

create table workflow_action_child_role_map(
  action_id                 integer
                            constraint wf_act_child_rl_map_child_fk
                            references workflow_actions(action_id),
  child_role_id             integer
                            constraint wf_act_child_rl_map_chld_rl_fk
                            references workflow_roles(role_id),
  parent_role_id            integer
                            constraint wf_act_child_rl_map_prnt_rl_fk
                            references workflow_roles(role_id),
  mapping_type              char(40)
                            constraint wf_act_child_rl_map_type_ck
                            check (mapping_type in 
                                ('per_role','per_user'))
                            default 'per_role',
  constraint wf_act_chld_rl_map_pk
  primary key (action_id, child_role_id)
);

comment on column workflow_action_child_role_map.mapping_type is '
  If per user, we create a child workflow per user who is a member of any of the parties assigned to the parent_role.
  If per role, we create just one child workflow, with the exact same parties that are in the parent_role.
  If more than one child_role has a mapping_type other than per_role, the cartesian product of these roles will be created.
';

create table workflow_case_parent_action(
  case_id                 integer 
                          constraint wf_case_child_cases_case_fk
                          references workflow_cases
                          constraint wf_case_child_cases_case_pk
                          primary key,
  parent_enabled_action_id
                          integer
                          constraint wf_case_child_cases_en_act_fk
                          references workflow_case_enabled_actions
                          constraint wf_case_child_cases_en_act_nn
                          not null
);

create index wf_cs_child_cs_en_act_idx on workflow_case_parent_action(parent_enabled_action_id);
alter table workflow_cases add
  top_case_id               integer
                            constraint wf_cases_top_case_id_fk
                            references workflow_cases(case_id)
                            on delete cascade;
update workflow_cases set top_case_id = case_id;


-- object_id can now be null, and doesn't have to be unique 
-- (since we're going to have plenty of rows with null object_id)
alter table workflow_cases drop constraint wf_cases_object_id_un;
alter table workflow_cases alter object_id drop not null;

-- Find case's object_id from the top_case_id
create or replace function workflow_case_log_entry__new (
    integer,                  -- entry_id
    varchar,                  -- content_type
    integer,                  -- case_id
    integer,                  -- action_id
    varchar,                  -- comment
    varchar,                  -- comment_mime_type
    integer,                  -- creation_user
    varchar                   -- creation_ip
) returns integer as '
declare
    p_item_id           alias for $1;
    p_content_type      alias for $2;
    p_case_id           alias for $3;
    p_action_id         alias for $4;
    p_comment           alias for $5;
    p_comment_mime_type alias for $6;
    p_creation_user     alias for $7;
    p_creation_ip       alias for $8;
        
    v_name                        varchar;
    v_action_short_name           varchar;
    v_action_pretty_past_tense    varchar;
    v_case_object_id              integer;
    v_item_id                     integer;
    v_revision_id                 integer;
begin
    select short_name, pretty_past_tense
    into   v_action_short_name, v_action_pretty_past_tense
    from   workflow_actions
    where  action_id = p_action_id;

    -- use case object as context_id
    select top.object_id
    into   v_case_object_id
    from   workflow_cases c, 
           workflow_cases top
    where  top.case_id = c.top_case_id
    and    c.case_id = p_case_id;

    -- build the unique name
    if p_item_id is not null then
        v_item_id := p_item_id;
    else
        select nextval
        into   v_item_id
        from   acs_object_id_seq;
    end if;
    v_name := v_action_short_name || '' '' || v_item_id;

    v_item_id := content_item__new (
        v_item_id,                   -- item_id
        v_name,                      -- name
        v_case_object_id,            -- parent_id
        v_action_pretty_past_tense,  -- title
        now(),                       -- creation_date
        p_creation_user,             -- creation_user
        v_case_object_id,            -- context_id
        p_creation_ip,               -- creation_ip
        ''t'',                       -- is_live
        p_comment_mime_type,         -- mime_type
        p_comment,                   -- text
        ''text'',                    -- storage_type
        ''t'',                       -- security_inherit_p
        ''CR_FILES'',                -- storage_area_key
        ''content_item'',            -- item_subtype
        p_content_type               -- content_type
    );

    -- insert the row into the single-column entry revision table
    select content_item__get_live_revision (v_item_id)
    into v_revision_id;

    insert into workflow_case_log_rev (entry_rev_id)
    values (v_revision_id);

    -- insert into workflow-case-log
    insert into workflow_case_log (entry_id, case_id, action_id)
    values (v_item_id, p_case_id, p_action_id);

    -- return id of newly created item
    return v_item_id;
end;' language 'plpgsql';
