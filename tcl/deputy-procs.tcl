ad_library {
    Procedures in the workflow::deputy namespace.
    
    @creation-date 2003-06-25
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::deputy {}

ad_proc -public workflow::deputy::new {
    {-user_id ""}
    {-deputy_id:required}
    {-start_day:required}
    {-end_day:required}
    {-message ""}
} {
    Create a new deputizing period for a user during which workflow
    tasks will be assigned to a deputee.

    @param user_id    The id of the user that is deputizing
    @param deputy_id  The id of the user to deputize to
    @param start_day The start date of the deputizing period. Must be on ANSI format "YYYY-MM-DD"
    @param end_day   The end date of the deputizing period. Must be on ANSI format "YYYY-MM-DD"
    @param message    Any message describing the deputizing

    @author Peter Marklund
} {
    if { [empty_string_p $user_id] } {
	set user_id [ad_conn user_id]
    }

    db_dml insert_deputy {}

    # Flush the role assignment info for all cases
    # to make sure cache is in sync with db
    # Do we also need to flush the workflow level cache here?
    workflow::case::flush_cache
}

ad_proc -public workflow::deputy::edit {
    {-user_id:required}
    {-deputy_id:required}
    {-start_day:required}
    {-end_day:required}
    {-message:required}
} {
    Edit deputy information for a certain user_id and deputy_id.

    @see workflow::deputy::new

    @author Peter Marklund
} {
    db_dml update_deputy {}
}

ad_proc -public workflow::deputy::delete {
    {-user_id:required}
    {-deputy_id:required}
} {
    Delete deputy information for a certain user_id and deputy_id.

    @author Peter Marklund
} {
    db_dml delete_deputy {}

    # Flush the role assignment info for all cases
    # to make sure cache is in sync with db
    # Do we also need to flush the workflow level cache here?
    workflow::case::flush_cache
}
