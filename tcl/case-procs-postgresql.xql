<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::case::fsm::get_info_not_cached.select_case_info">
    <querytext>
      select c.case_id,
             c.workflow_id,
             c.object_id,
             s.state_id,
             s.short_name as state_short_name,
             s.pretty_name as pretty_state,
             s.hide_fields as state_hide_fields
      from   workflow_cases c,
             workflow_case_fsm cfsm left outer join
             workflow_fsm_states s on (s.state_id = cfsm.current_state)
      where  c.case_id = :case_id
      and    cfsm.case_id = c.case_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::get_assignees_not_cached.select_assignees">
    <querytext>
        select m.party_id, 
               p.email,
               acs_object__name(m.party_id) as name
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
               r.content as comment_string,
               r.mime_type as comment_mime_type,
               d.key,
               d.value
        from   workflow_case_log l join 
               workflow_actions a using (action_id) join 
               cr_items i on (i.item_id = l.entry_id) join 
               acs_objects io on (io.object_id = i.item_id) join 
               cc_users iou on (iou.user_id = io.creation_user) join
               cr_revisions r on (r.revision_id = i.live_revision) left outer join 
               workflow_case_log_data d using (entry_id)
        where  l.case_id = :case_id
        order  by creation_date
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::notify.select_object_name">
    <querytext>
        select acs_object__name(:object_id) as name
    </querytext>
   </fullquery>

   <partialquery name="workflow::case::role::get_search_query.select_search_results">
    <querytext>
        select distinct acs_object__name(p.party_id) || ' (' || p.email || ')' as label, p.party_id
        from   [ad_decode $subquery "" "cc_users" $subquery] p
        where  upper(coalesce(acs_object__name(p.party_id) || ' ', '')  || p.email) like upper('%'||:value||'%')
        order  by label
    </querytext>
  </partialquery>

  <fullquery name="workflow::case::role::get_picklist.select_options">
    <querytext>
        select acs_object__name(p.party_id) || ' (' || p.email || ')'  as label, p.party_id
        from   parties p
        where  p.party_id in ([join $party_id_list ", "])
        order  by label
    </querytext>
  </fullquery>

</queryset>
