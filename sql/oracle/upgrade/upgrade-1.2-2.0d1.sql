--
-- Adds timed actions, plus some missing delete cascade indices
-- 
-- @cvs-id $Id$
--


alter table workflow_actions add (timeout_seconds integer);


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


-- Missing delete cascade index in Oracle

create index workflow_case_log_action_id on workflow_case_log (action_id);
create index workflow_case_log_case_id on workflow_case_log (case_id);

