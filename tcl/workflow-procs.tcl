ad_library {
    Procedures in the workflow namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval ::workflow {}

ad_proc -public ::workflow::add {
    {-short_name:required}
    {-pretty_name:required}
    {-object_id:required}
    {-object_type "acs_object"}
} {
    Creates a new workflow.

    @param short_name  For referring to the workflow from Tcl code. Use Tcl variable syntax.
    @param pretty_name A human readable name for the workflow for use in the UI.
    @param object_id   The id of an ACS Object indicating the scope the workflow. 
                       Typically this will be the id of a package type or a package instance
                       but it could also be some other type of ACS object within a package, for example
                       the id of a bug in the Bug Tracker application.
    @param object_type The type of objects that the workflow will be applied to. Valid values are in the
                       acs_object_types table. The parameter is optional and defaults to acs_object.

    @author Peter Marklund
} {
    # Auditing information for the acs_objects table
    if { [ad_conn isconnected] } {            
        set creation_user [ad_conn user_id]
        set creation_ip [ad_conn peeraddr]        
    } else {
        # No HTTP request so we have don't have IP and user info
        set creation_user ""
        set creation_ip ""
    }

    # It makes sense that the workflow inherits permissions from the object (typically package type or package instance)
    # that sets the scope of the workflow
    set context_id $object_id

    db_dml do_insert {}
}
