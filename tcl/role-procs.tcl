ad_library {
    Procedures in the workflow::role namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::role {}

#####
#
#  workflow::role namespace
#
#####

ad_proc -public workflow::role::add {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
} {
    Creates a new role for a certain workflow.
    
    @param workflow_id
    @param short_name
    @param pretty_name
    
    @author Peter Marklund
} {        
    set role_id [db_nextval "workflow_roles_seq"]

    db_dml do_insert {}
}

ad_proc -public workflow::role::get_id {
    {-workflow_id:required}
    {-short_name:required}
} {
    Return the role_id of the role with the given short_name in the given workflow.

    @param workflow_id The ID of the workflow
    @param short_name The short_name of the role
    @return role_id of the desired role, or the empty string if it can't be found.
} {
    return [db_string select_role_id {} -default {}]
}
