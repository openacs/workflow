<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::get_id.select_workflow_id">
    <querytext>
      select workflow_id
      from   workflows
      where  object_id = :object_id
      and    short_name = :short_name                        
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_initial_action.select_initial_action">
    <querytext>
      select action_id
      from   workflow_initial_action
      where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

</queryset>
