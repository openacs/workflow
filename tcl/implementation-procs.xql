<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::impl::role_default_assignees::creation_user::get_assignees.select_creation_user">
    <querytext>
      select creation_user
      from   acs_objects
      where  object_id = :object_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::impl::role_default_assignees::creation_user::get_assignees.select_static_asignees">
    <querytext>
      select party_id
      from   workflow_role_default_parties
      where  role_id = :role_id
    </querytext>
  </fullquery>


  <fullquery name="workflow::impl::role_assignee_pick_list::select_current_assignees">
    <querytext>
      select party_id
      from   workflow_case_role_party_map
      where  role_id = :role_id 
      and    case_id = :case_id
    </querytext>
  </fullquery>

</queryset>
