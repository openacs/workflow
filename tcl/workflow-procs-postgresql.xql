<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::new.do_insert">
    <querytext>
        select workflow__new (
            :short_name,
            :pretty_name,
            :package_key,            
            :object_id,
            :object_type,
            :creation_user,
            :creation_ip,
            :context_id
        );
    </querytext>
  </fullquery>

  <fullquery name="workflow::delete.do_delete">
    <querytext>
        select workflow__delete(:workflow_id);
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order),0) + 1
        from   workflow_callbacks
        where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

 </queryset>
