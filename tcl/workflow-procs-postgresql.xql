<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::add.do_insert">
    <querytext>
        select workflow__new (:short_name,
                              :pretty_name,
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
        select acs_object__delete(:workflow_id);
    </querytext>
  </fullquery>

</queryset>
