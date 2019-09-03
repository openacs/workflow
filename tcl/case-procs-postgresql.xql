<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::case::delete.delete_case">
    <querytext>
	select workflow_case_pkg__delete(:case_id)
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::enable.insert_enabled">
    <querytext>
        insert into workflow_case_enabled_actions
              (enabled_action_id, 
               case_id, 
               action_id, 
               parent_enabled_action_id, 
               assigned_p, 
               execution_time)
        select :enabled_action_id, 
               :case_id, 
               :action_id, 
               :parent_enabled_action_id, 
               :db_assigned_p, 
               current_timestamp + a.timeout
        from   workflow_actions a
        where  a.action_id = :action_id
    </querytext>
  </fullquery>

</queryset>
