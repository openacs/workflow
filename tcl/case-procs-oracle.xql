<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

  <fullquery name="workflow::case::fsm::get_info_not_cached.select_case_info">
    <querytext>
      select c.case_id,
             c.top_case_id,
             c.workflow_id,
             top.object_id,
             s.state_id,
             s.short_name as state_short_name,
             s.pretty_name as pretty_state,
             s.hide_fields as state_hide_fields
      from   workflow_cases c,
             workflow_cases top,
             workflow_case_fsm cfsm,
             workflow_fsm_states s
      where  c.case_id = :case_id
      and    cfsm.case_id = c.case_id
      and    top.case_id = c.top_case_id
      and    s.state_id (+) = cfsm.current_state
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::timed_actions_sweeper.select_timed_out_actions">
    <querytext>
        select case_id, 
               action_id
        from   workflow_case_enabled_actions
        where  execution_time <= sysdate
        and   enabled_state = 'enabled'
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::get_assignees_not_cached.select_assignees">
    <querytext>
        select m.party_id, 
               p.email,
               acs_object.name(m.party_id) as name
        from   workflow_case_role_party_map m,
               parties p
        where  m.case_id = :case_id
        and    m.role_id = :role_id
        and    p.party_id = m.party_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::get_activity_log_info_not_cached.select_log">
    <querytext>
        select l.entry_id,
               l.case_id,
               l.action_id,
               a.short_name as action_short_name,
               a.pretty_past_tense as action_pretty_past_tense,
               io.creation_user,
               iou.first_names as user_first_names,
               iou.last_name as user_last_name,
               iou.email as user_email,
               io.creation_date,
               to_char(io.creation_date, 'fmMM/DDfm/YYYY') as creation_date_pretty,
               blob_to_string(r.content) as comment_string, -- needs il8-ing...
               r.mime_type as comment_mime_type,
               d.key,
               d.value
        from   workflow_case_log l,
               workflow_actions a,
               cr_items i,
               acs_objects io,
               cc_users iou,
               cr_revisions r,
               workflow_case_log_data d
        where  l.case_id = :case_id
          and  l.action_id = a.action_id
          and  i.item_id = l.entry_id
          and  io.object_id = i.item_id
          and  iou.user_id = io.creation_user
          and  r.revision_id = i.live_revision
          and  d.entry_id (+) = l.entry_id
        order  by creation_date
    </querytext>
  </fullquery>


  <partialquery name="workflow::case::role::get_search_query.select_search_results">
    <querytext>
        select distinct acs_object.name(p.party_id) || ' (' || p.email || ')' as label, p.party_id
        from   [ad_decode $subquery "" "cc_users" $subquery] p
        where  upper(nvl(acs_object.name(p.party_id) || ' ', '')  || p.email) like upper('%'||:value||'%')
        order  by label
    </querytext>
  </partialquery>

  <fullquery name="workflow::case::role::get_picklist.select_options">
    <querytext>
        select acs_object.name(p.party_id) || ' (' || p.email || ')'  as label, p.party_id
        from   parties p
        where  p.party_id in ([join $party_id_list ", "])
        order  by label
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::state_changed_handler.select_enabled_actions">
    <querytext>
      select a.action_id
      from   workflow_cases c,
             workflow_actions a
      where  c.case_id = :case_id
      and    a.workflow_id = c.workflow_id
      and    not exists (select 1 
                         from   workflow_initial_action wia
                         where  wia.workflow_id = c.workflow_id
                         and    wia.action_id = a.action_id)
      and    (a.always_enabled_p = 't' 
             or exists (select 1 
                        from   workflow_case_fsm cfsm,
                               workflow_fsm_action_en_in_st waeis
                        where  cfsm.case_id = c.case_id
                        and    waeis.state_id = cfsm.current_state
                        and    waeis.action_id = a.action_id))
      order by a.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::notify.select_object_name">
    <querytext>
        select acs_object.name(:object_id) as name from dual
    </querytext>
   </fullquery>

   <fullquery name="workflow::case::delete.delete_case">
    <querytext>
        begin
            :1 := workflow_case_pkg.del(:case_id);
        end;
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::execute.set_completed">
    <querytext>
       update workflow_case_enabled_actions
       set    enabled_state = 'completed',
              executed_date = sysdate
       where  case_id = :case_id
       and    action_id = :action_id
       and    enabled_state = 'enabled'
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::enable.insert_enabled">
    <querytext>
        insert into workflow_case_enabled_actions
        (enabled_action_id, case_id, action_id, enabled_state, execution_time)
        select :enabled_action_id, :case_id, a.action_id, 'enabled', sysdate + a.timeout_seconds/(24*60*60)
        from   workflow_actions a
        where  a.action_id = :action_id
    </querytext>
  </fullquery>

</queryset>
