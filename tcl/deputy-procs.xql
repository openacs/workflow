<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::deputy::new.insert_deputy">
    <querytext>
	insert into workflow_deputies
		(user_id, deputy_user_id, start_date, end_date, message)
	values (:user_id, :deputy_id, to_date(:start_day, 'YYYY-MM-DD'), to_date(:end_day, 'YYYY-MM-DD'), :message)
    </querytext>
  </fullquery>

  <fullquery name="workflow::deputy::edit.update_deputy">
    <querytext>
	update workflow_deputies
	    set start_date = to_date(:start_day, 'YYYY-MM-DD'), 
	        end_date = to_date(:end_day, 'YYYY-MM-DD'),
	        message = :message
	where user_id = :user_id
	  and deputy_user_id = :deputy_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::deputy::delete.delete_deputy">
    <querytext>
	delete from workflow_deputies
	where user_id = :user_id
	  and deputy_user_id = :deputy_id
    </querytext>
  </fullquery>

</queryset>


