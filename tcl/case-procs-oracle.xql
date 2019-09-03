<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

   <fullquery name="workflow::case::delete.delete_case">
    <querytext>
        begin
            :1 := workflow_case_pkg.del(:case_id);
        end;
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
               sysdate + a.timeout_seconds/(24*60*60)
        from   workflow_actions a
        where  a.action_id = :action_id
    </querytext>
  </fullquery>

</queryset>
