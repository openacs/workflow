ad_library {
    Procedures in the workflow::action namespace.
    
    @creation-date 9 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval ::workflow::action {}

ad_proc -public ::workflow::action::add {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-assigned_role {}}
    {-allowed_roles {}}
    {-privileges {}}
} {
    This procedure should never be invoked from application code. Instead use
    a procedure for a certain workflow implementation, such as for example
    workflow::fsm::action::add for Finite State Machine workflows.

    @param workflow_id            The id of the FSM workflow to add the action to
    @param short_name             Short name of the action for use in source code.
                                  Should be on Tcl variable syntax.
    @param pretty_name            Human readable name of the action for use in UI.
    @param pretty_past_tense      Past tense of pretty name
    @param assigned_role          Users in this role are expected (obliged) to take 
                                  the action.
    @param allowed_roles          Users in these roles are allowed to take the action.
    @param privileges             Users with these privileges on the object 
                                  treated by the workflow (i.e. a bug in the 
                                  Bug Tracker) will be allowed to take this 
                                  action.

    @return The id of the created action

    @see workflow::fsm::action::add

    @author Peter Marklund
} {
    db_transaction {
        # Insert basic action info
        set action_id [db_nextval "wf_workflow_fsm_actions_seq"]
        db_dml insert_action {}

        # Record which roles are allowed to take action
        foreach allowed_role $allowed_roles {
            db_dml insert_allowed_role {}
        }

        # Record which privileges enable the action
        foreach privilege $privileges {
            db_dml insert_privilege {}
        }
    }

    return $action_id
}
