<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.7</version></rdbms>

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
               acs_object.name(m.party_id) as name
        from   workflow_case_role_party_map m,
               parties p
        where  m.case_id = :case_id
        and    m.role_id = :role_id
        and    p.party_id = m.party_id
    </querytext>
  </fullquery>

</queryset>
