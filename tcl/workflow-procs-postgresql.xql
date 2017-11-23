<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::edit.do_insert">
    <querytext>
        select workflow__new (
            :attr_short_name,
            :attr_pretty_name,
            :attr_package_key,            
            :attr_object_id,
            :attr_object_type,
            :attr_creation_user,
            :attr_creation_ip,
            :attr_context_id
        );
    </querytext>
  </fullquery>

  <fullquery name="workflow::delete.do_delete">
    <querytext>
        select workflow__delete(:workflow_id);
    </querytext>
  </fullquery>
  
 </queryset>
