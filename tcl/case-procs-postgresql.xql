<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::case::insert.select_initial_state">
    <querytext>
      select state_id
      from   workflow_fsm_states
      where  workflow_id = :workflow_id
      order  by sort_order
      limit  1
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::get_assignees.select_assignees">
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

  <fullquery name="workflow::case::get_activity_html.select_log">
    <querytext>
        select l.entry_id,
               l.case_id,
               l.action_id,
               a.short_name as action_short_name,
               a.pretty_name as action_pretty_name,
               a.pretty_past_tense as action_pretty_past_tense,
               io.creation_user,
               iou.first_names as user_first_names,
               iou.last_name as user_last_name,
               iou.email as user_email,
               io.creation_date,
               to_char(io.creation_date, 'fmMM/DDfm/YYYY') as creation_date_pretty,
               r.content as comment,
               r.mime_type as comment_mime_type
        from   workflow_case_log l join 
               workflow_actions a using (action_id) join 
               cr_items i on (i.item_id = l.entry_id) join 
               acs_objects io on (io.object_id = i.item_id) join 
               cc_users iou on (iou.user_id = io.creation_user) join
               cr_revisions r on (r.revision_id = i.live_revision)
        where  l.case_id = :case_id
        order  by creation_date
    </querytext>
  </fullquery>

</queryset>
