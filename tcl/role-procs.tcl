ad_library {
    Procedures in the workflow::role namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::role {

    ad_proc -public add {
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
        set role_id [db_nextval "wf_workflow_roles_seq"]

        db_dml do_insert {}
    }
}
