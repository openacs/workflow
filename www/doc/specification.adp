
<property name="context">{/doc/workflow {Workflow}} {Workflow Functional Specification}</property>
<property name="doc(title)">Workflow Functional Specification</property>
<master>
<h1>Workflow Functional Specification</h1>
<a href=".">Workflow Documentation</a>
 : Functional Specification
<hr>
<p>By <a href="http://www.pinds.com">Lars Pind</a>
</p>
<h2>Overview</h2>
<p>I recently built a typical workflow-based application, <a href="http://clients.museatech.net/bug-tracker/">bug-tracker</a>, and
decided against using the acs-workflow package that I myself built.
That&#39;s not a good recommendation. We need to fix that.</p>
<h2>Goals</h2>
<p>The goal is to implement a workflow package that:</p>
<ul>
<li>Is ideally suited for at least 3 use-cases: Bug-tracker,
CMS-style publication process, and simple approval.</li><li>Gives people a usable UI.</li><li>Can be used entirely through a clean Tcl API</li><li>Doesn&#39;t require people to learn Petri Nets</li><li>Is much easier for developers to use in their applications</li>
</ul>
<p>Gripes with the current acs-workflow:</p>
<ul>
<li>Engine is in PL/SQL, not in Tcl, which makes it hard to write
callbacks.</li><li>Petri net is just too complicated for people to learn how to
use, and there are too many ways for them to mess up. The primary
benefit is parallel routing, which I&#39;ve never actually come
across any applications that seriously needed.</li><li>The UI sucks, and it&#39;s really hard to use workflow without
using the interface.</li><li>Graphviz is actually not terribly great at displaying workflow
nets, as it tries to fit everything into a circle, whereas most of
the time with workflow what you really want is to have it appear as
a nice sequence of events with some loops back here and there.</li><li>It&#39;s too restrictive and inflexible. It&#39;s hard to
change your mind and go back, or to manually bash the case into a
certain state.</li><li>Also, it was never finished. Unfortunately, finishing it would
be a tremendous amount of work for limited benefit.</li><li>Data model has some big issues: Workflows are object types.
Workflows aren&#39;t tied to packages, and the context idea
isn&#39;t working very well. It&#39;s based on petri nets.</li>
</ul>
<h2>Finite State Machine</h2>
<p>Take bug-tracker as an example. The bug-tracker workflow and
user interface can be defined as:</p>
<dl>
<dt>Roles</dt><dd><ul>
<li>Submitter</li><li>Assignee</li>
</ul></dd><dt>States</dt><dd><ul>
<li>Open</li><li>Resolved</li><li>Closed</li>
</ul></dd><dt>Actions</dt><dd><ul>
<li>Resolve: Enabled in states open and resolved; changes state to
resolved.</li><li>Close: Enabled in state resolved; changes state to closed.</li><li>Reopen: Enabled in states resolved, closed; changes state to
open.</li><li>Edit: Enabled in all states; no changes to state.</li><li>Comment: Enabled in all states; no changes to state.</li><li>Reassign: Enabled in states open, resolved; no changes to
state.</li>
</ul></dd>
</dl>
<p>I&#39;ve finally come to the realization that we&#39;ll be
better off in the short to medium term with just a well-functioning
implementation of a finite state machine based workflow module. In
general, a workflow consists of a finite set of states, and a
finite set of actions. Each action has a set of states in which
it&#39;s enabled, or it can be always enabled in all states. And
each action can cause the workflow case to move into a new state,
or it can leave the state unaltered.</p>
<p>Note that the ability to have an action enabled in more than one
state is a convenience, and not part of the mathematical model of
finite state machines. Likeways with actions that don&#39;t change
the state. But it&#39;s mighty convenient, as you&#39;ve seen
illustrated by the bug-tracker example above.</p>
<h2>Workflows</h2>
<p>A workflow is a set of roles, actions, and states, and their
relations.</p>
<p>A workflow is associated with an object, which would typically
be one of the following:</p>
<ol>
<li>A <strong>package type</strong>: This is the default workflow
for the bug-tracker package.</li><li>A <strong>package instance</strong>: This is the default
workflow for a particular instance of the bug-tracker package.</li><li>A <strong>single case</strong>: Future versions could allow you
to customize your workflow for a particular bug or content
story.</li>
</ol>
<p>There&#39;s also a short_name, so you can easily distinguish
between multiple workflows for the same package, e.g., one for
handling the bug, and another for approving creation of new
versions or components in the bug-tracker.</p>
<p>A workflow is also associated with an <strong>object
type</strong>. The reason for this is that assignments will
frequently depend on attributes of the specific object for the
case. In bug-tracker, for example, the default assignee for a bug
will be the maintainer of the component in which the bug has been
found. The bug-tracker will provide one or more assignment service
contract implementations, which, given the bug_id will give you the
component maintainer, or the project maintainer. These can be used
to set up automatic assignment through a nice web-based user
interface.</p>
<p>When you create a new workflow case for a specific object, we
will check that this object descends from the object type for which
the workflow is for. If your workflow is general enough to work for
all object types, then you can simply associate it with the common
ancestor of all objects, 'acs_object'.</p>
<p>When you create a new instance of the bug-tracker, we would
<strong>make a copy</strong> of the default bug-tracker workflow
for your particular package, so that you can make local changes to
the workflow, to the assignments, etc.</p>
<p>A workflow can have <strong>side-effects</strong>, which fire
when <strong>any</strong> action is triggered on that workflow.
These fire after the specific actions. See more under action
side-effects. These are declared as a standard
"Action_SideEffect" service contract implementation.</p>
<p>Another service contract on the workflow level is the
<strong>activity log entry title formatting</strong> contract.
Using a side-effect callback, you can store additional key/value
pairs in the activity log. You can use the title formatting service
contract to pull these out, along with any other data you like, and
use them to format the title of the log entry for display.</p>
<h2>Roles</h2>
<p>A workflow has a set of roles. For bug-tracker, this is
Submitter, and Assignee. More complex bug-tracker workflows, could
add Triager and Tester. For a typical pulication workflow,
you&#39;d have Author, Editor, and Publisher. Normally, you&#39;d
always include an 'Administrator' role.</p>
<p>Each role is associated with one or more actions in the
workflow. The assignee is assigned to the 'Resolve' action,
but also has permission to perform the Edit, Comment and Reassign
actions. The submitter is assigned to the 'Close' action,
but also has permission to 'Reopen', 'Edit',
'Comment', and possibly 'Reassign'.</p>
<p>The idea behind introducing roles is that you do not want to go
through the bother of assigning each action individually, when
normally they are grouped together.</p>
<p>Then, as the workflow case unfolds, people are given roles--you
will be the submitter, you will be the assignee. Roles can get
reassigned at any time.</p>
<h3>Default Assignment</h3>
<p>The tricky part, however, is the rules saying who should be
assigned by default, or who <em>can</em> be assigned to this role.
First, let&#39;s look at how the <strong>default assignees</strong>
can be determined.</p>
<ol>
<li>If you only have one publisher, then you simply want to assign
the Publisher role to that publisher always. That&#39;s called a
<strong>static assignment</strong>, and the information about that
current assignee is kept in the workflow data model.</li><li>The Submitter role in bug-tracker, you want to assign to
whoever opened the bug, namely the <strong>object creation
user</strong>.</li><li>The Assignee role in bug-tracker is given to the maintainer of
the component in which the bug was found. This is an example of a
completely <strong>application-specific</strong> assignment, one
which is only relevant for bug-tracker bug objects, because we need
to know the particular bug-tracker data model for this to
work.</li>
</ol>
<p>These different options are supplied by programmers as
implementations of a particular service contract (see below under
<a hred="#service-contracts">service contracts</a>).</p>
<p>In the definition of a workflow, you can select <strong>an
ordered list of default assignment methods</strong> Each will be
tried in the order you specify. The first to return a non-empty
list of assignees is the one which will be used, and the rest
won&#39;t get called. So for example you can say "first try
component maintainer, and if non is specified, use the project
maintainer".</p>
<p>The workflow package will supply a few standard
implementations:</p>
<ul>
<li>Creation user: Assign to the user who created the given
object.</li><li>Static assignee: Use the static assignment from the workflow
definition.</li>
</ul>
<p>Default assignment is done in a lazy fashion, in that we
don&#39;t try to find the default assignees until we need to. We
need to the first time an action assigned to that role is enabled.
This allows your default assignment to depend on things that
happened in prior tasks.</p>
<h3>Reassignment</h3>
<p>Now, let&#39;s look at what happens when you want to reassign a
role to someone else. the</p>
<ol>
<li>If you want to reassign the role, the user interface offers a
<strong>pick-list</strong> of the users and groups which you&#39;re
most likely to want to reassign the role to. Who they are will
depend on the particular application. One common idea is to display
the users who are currently assigned to this role in other
cases.</li><li>If the desired person or group wasn&#39;t in the pick-list, you
can <strong>search</strong>. The search is conducted among all the
users who could possibly be assigned to this role, which, again,
will depend on the application. It could be all registered users on
the site, it could be all members of the nearest surrounding
subsite, it could be all members of a particular named group, or it
could be some other calculation based on the application.</li>
</ol>
<p>A couple of default implementations will be supplied by the
workflow package. For the pick-list:</p>
<ul><li>Current assigness: Returns the list of parties who are
currently assigned to this role in this workflow (for example, all
the current assignees in this bug-tracker instance).</li></ul>
<p>For the search query:</p>
<ul>
<li>Registered users: No limitation, search among all registered
users. Simply returns a query name for "cc_users".</li><li>Nearest subsite members: Limit to members of the nearest
subsite above the current package.</li><li>Static allowed assignment: The users defined as the allowed
parties in the workflow_role_allowed_parties table.</li>
</ul>
<h2>Actions</h2>
<p>In order to determine who are <em>supposed</em> to perform an
action, and who are <em>allowed</em> to perform the action, we let
you specify these three things for each action:</p>
<ul>
<li>
<strong>Assigned role(s)</strong>: People who are mapped to
this role will be <em>assigned</em> to this action, e.g., the
submitter is assigned to the Close action once the bug is resolved.
When you&#39;re assigned to something, you&#39;re expected to go
and do something about it.</li><li>
<strong>Allowed role(s)</strong>: People who are mapped to this
role will have the <em>permission</em> to perform this action,
e.g., the submitter is allowed to Reopen the bug once it&#39;s
resolved, but not assigned to it. She&#39;s only assigned to
"Close".</li><li>
<strong>Privileges</strong>: People who have these privileges
on the object pointed to by workflow_case.object_id (e.g. the bug
object for bug-tracker) will also have <em>permission</em> to do
perform this action. Same as above, but allows for using
permissions to grant 'feedback', 'write', and
'admin', for example.</li>
</ul>
<p>Actions can also have <strong>side-effects</strong>, which
simply means that whenever an action is triggered, one or more
specified service contract implementations will get executed. These
side-effects are executed <strong>after</strong> all other updates,
both to the case object, and to the workflow tables, have been
completed.</p>
<h2>States</h2>
<p>This is specific to the FSM-model. A workflow has a finite set
of states, for example "open", "resolved", and
"closed". A case will always be in exactly one such
state. When you perform an action, the workflow can be pushed into
a new state.</p>
<p>There will be one initial state, which the workflow will start
out in. This will be the first state according to the sort order
from workflow_fsm_states</p>
<p>States have almost no information associated with them,
they&#39;re simply used to govern which actions are available.</p>
<h2>Cases</h2>
<p>A case is the term for a workflow in action. A case always
revolves around a specific object. and we currently only allow one
case for one object. That is, you can only have one workflow in
process for one object.</p>
<p>The case holds information about the current state, the current
assignments, and an activity log over everything that happens on
the case.</p>
<h2>Data Model</h2>
<pre class="code">
//--------------------//
//  Workflow level    //
//--------------------//

create table workflows (
  workflow_id             integer ... primary key, references acs_objects
  short_name              varchar ...
  pretty_name             varchar ...
  object_id               integer ... references acs_objects
  -- object_id points to either a package type, 
  -- package instance, or single workflow case
  object_type             varchar ... references acs_object_types
  -- which object type (or its subtypes) is this workflow designed for
  unique (object_id, short_name)
);

create table workflow_callbacks (
  workflow_id             integer ... references workflows
  acs_sc_impl_id          integer ... references acs_sc_impls
  sort_order              integer ...
    
  constraint ...
  primary key (workflow_id, acs_sc_impl_id)
);

create table workflow_roles (
  role_id                 integer ... primary key
  workflow_id             integer ... references workflows
  short_name              varchar ...
  pretty_name             varchar ...
  
);

create table workflow_role_default_parties (
  role_id                 integer ... references workflow_roles
  party_id                integer ... references parties

  constraint ... 
  primary key (role_id, party_id)
);

create table workflow_role_allowed_parties (
  role_id                 integer ... references workflow_roles
  party_id                integer ... references parties

  constraint ... 
  primary key (role_id, party_id)
);

create table workflow_role_callbacks (
  role_id                 integer ... references workflow_roles
  acs_sc_impl_id          integer ... references acs_sc_impls
  -- this can be an implementation of any of the three assignment
  -- service contracts: DefaultAssignee, AssigneePickList, or 
  -- AssigneeSubQuery
  sort_order              integer ...
  
  constraint ...
  primary key (role_id, acs_sc_impl_id)
);

create table workflow_actions (
  action_id               integer ... primary key
  workflow_id             integer ... references workflows
  sort_order              integer ...
  short_name              varchar ...
  pretty_name             varchar ...
  pretty_past_tense       varchar ...
  assigned_role           integer ... references workflow_roles
);

create table workflow_action_allowed_roles (
  action_id               integer ... references workflow_actions
  role_id                 integer ... references workflow_roles
);

create table workflow_action_privileges (
  action_id               integer ... references workflow_actions
  privilege               varchar ... references acs_privileges
);

create table workflow_action_callbacks (
  action_id               integer ... references workflow_actions
  acs_sc_impl_id          integer ... references acs_sc_impls
  sort_order              integer ...
    
  constraint ...
  primary key (action_id, acs_sc_impl_id)
);

//  Finite State Machine model //

create table workflow_fsm_states (
  state_id                integer ... primary key
  workflow_id             integer ... references workflows
  sort_order              integer ...
  short_name              varchar ...
  pretty_name             varchar ...
);

create table workflow_fsm_actions (
  action_id               integer ... primary key ... references workflow_actions
  new_state               integer ... references workflow_fsm_states (can be null)
);

create table workflow_fsm_action_enabled_in_states (
  action_id               integer ... references workflow_fsm_actions
  state_id                integer ... references workflow_fsm_states
);

create table workflow_fsm (
  workflow_id             integer ... primary key, references workflows
  initial_state           integer ... references workflow_fsm_states
);

//--------------------//
//  Case level        //
//--------------------//

create table workflow_cases (
  case_id                 integer ... primary key
  workflow_id             integer ... references workflows
  object_id               integer ... references acs_objects ... unique
  -- the object which this case is about, e.g. object_id of the bug
);

create table workflow_case_log (
  entry_id                integer ... primary key
  case_id                 integer ... references workflow_cases
  action_id               integer ... references workflow_actions
  user_id                 integer ... references users
  action_date             timestamp not null default now(),
  comment                 text ...
  comment_format          varchar ...
);

create table workflow_case_log_data (
  entry_id                integer ... references workflow_case_log
  key                     varchar
  value                   varchar

  constraint ...
  primary key (entry_id, key)
);

create table workflow_case_role_assigned_parties (
  case_id                 integer ... references workflow_cases
  role_id                 integer ... references workflow_roles
  party_id                integer ... references parties

  constraint ...
  primary key (case_id, role_id, party_id)
);


//  Finite State Machine model //

create table workflow_case_fsm (
  case_id                 integer ... references workflow_cases
  current_state           integer ... references workflow_fsm_states
);


</pre>
<h2><a name="service-contracts" id="service-contracts">Service
Contracts</a></h2>
<pre class="code">
<strong>workflow.Role_DefaultAssignees:</strong>
  GetObjectType -&gt; string
  GetPrettyName -&gt; string
  GetAssignees (case_id, object_id, role_id) -&gt; { list of party_id }
</pre>
<pre class="code">
<strong>workflow.Role_AssigneePickList</strong>
  GetObjectType -&gt; string
  GetPrettyName -&gt; string
  GetPickList (case_id, object_id, role_id) -&gt; { list of party_id }
</pre>
<pre class="code">
<strong>workflow.Role_AssigneeSubQuery</strong>
  GetObjectType -&gt; string
  GetPrettyName -&gt; string
  GetSubQueryName (case_id, object_id, role_id) -&gt; { subquery_name { bind variable list } }
</pre>
<pre class="code">
<strong>workflow.Action_SideEffect</strong>
  GetObjectType -&gt; string
  GetPrettyName -&gt; string
  DoSideEffect (case_id, object_id, action_id, entry_id) -&gt; (none)
</pre>
<pre class="code">
<strong>workflow.ActivityLog_FormatTitle</strong>
  GetObjectType -&gt; string
  GetPrettyName -&gt; string
  GetTitle (entry_id) -&gt; title
</pre>
<p>The <strong>GetObjectType</strong> method is used for the
service contract implementation to tell which object types it is
valid for. For example, a DefaultAssignee implementation can look
at a bug, find out which component it is found in, then look up the
component definition to find the default maintainer. This
implementation, though, is <em>only</em> valid for objects of type
'bt_bugs', or any descendants thereof. Thus, this is what
the GetObjectType call would return for this implementation. If
your implementation is valid for any ACS Object, then simply return
'acs_object', as this is the mother of all objects.</p>
<p>The <strong>GetPrettyName</strong> method will be run through a
localization filter, meaning that any occurrence of the
<code>#<em>message-key</em>#</code> notation will be replaced with
a message catalog lookup for the current domain.</p>
<p>The <strong>AssigneeQuery</strong> service contract probably
needs a little explanation. You&#39;re supposed to supply a valid
subquery, which will select the columns party_id, name, email, and
screen_name (nulls are okay) of all the parties that a role can
possibly be assigned to. A simple version could simply be
"<code>cc_users</code>". Another would be:</p>
<pre class="code">
select u.user_id as party_id, 
       u.first_names || ' ' || u.last_names as name,
       u.email,
       u.screen_name
from   cc_users u
where  (some condition)
</pre>
<p>This would then typically be used like this:</p>
<pre class="code">
select distinct 
       q.party_id, 
       q.name || ' (' || u.email || ')' as name_and_email
from   (<strong><em>your subquery goes here</em></strong>) q
where  upper(coalesce(q.name, '') || 
          q.email || ' ' || 
          coalesce(q.screen_name, '')) 
          like upper('%'||:value||'%')
order  by name_and_email
</pre>
<p>Now, one little caveat is that you have to return the query
dispatcher <strong>query name, not the actual query</strong>. The
query name will then get passed to <strong>db_map</strong> to
produce the actual subquery.</p>
<p>Workflow will supply these service contract implementations by
default:</p>
<dl>
<dt>workflow.Role_DefaultAssignee</dt><dd><ul>
<li>Creation user: Returns the creation_user of the given
object.</li><li>Status assignee: Returns the contents of the
workflow_role_default_parties table.</li>
</ul></dd><dt>workflow.Role_AssigneePickList</dt><dd><ul>
<li>Current assignees: Returns the list of parties who are
currently assigned to this role in some case in this workflow.</li><li>Static allowed assignees: Search through the contents of the
workflow_role_allowed_parties table.</li>
</ul></dd><dt>workflow.Role_AssigneeSubQuery</dt><dd><ul>
<li>Registered users: Search through all registered users.</li><li>Static allowed assignees: Search through the contents of the
workflow_role_allowed_parties table.</li>
</ul></dd>
</dl>
<h2>Notifications</h2>
<p>You can sign up for notifications at several levels:</p>
<ol>
<li>Notify me of all actions to which I&#39;m assigned. You
don&#39;t have to manually go sign up for these notifications, but
you should be able to change the delivery method and
frequency.</li><li>Notify me of all activity on ...
<ol>
<li>Any case where I&#39;m assigned to some role.</li><li>A particular case (one bug-tracker bug)</li><li>All cases in the particular workflow (entire bug-tracker
project)</li>
</ol>
</li>
</ol>
<p>You should always receive at most one notification per activity.
They&#39;re sent out in the order in which they&#39;re listed here,
and if you get the first, you won&#39;t get the second, third or
fourth; if you get the second, you won&#39;t get the third or
fourth, etc.</p>
<p>A special case is that the first notification isn&#39;t
optional. You don&#39;t have to manually go sign up for those
notifications, and you can&#39;t turn them off entirely. You can
still change the delivery method and the frequency, though.</p>
<p>In order to implement this, we need to make three fairly trivial
enhancements to the notifications package.</p>
<ol>
<li>We need to be able to pass on the list of already notified
users from one call of <code>notification::new</code> to the next.
So <code>notification::new</code> needs to take a parameter like
<code>-already_notified</code> and to not notify those again, and
likewise, to return the list of users notified by the given
notification.</li><li>We need to be able to limit notifications to only a subset of
the subscribed base. If you have a subscription on "any case
where I&#39;m assigned to some role", that&#39;s a dynamic
relationship. So the call to <code>notification::new</code> would
take as a parameter the list of people who are assigned to some
role on this particular case. Only people who are subscribed
<em>and</em> on that list will get notified. I can&#39;t think of a
good name for such a parameter, perhaps
<code>-positive_list</code>.</li><li>Finally, we need to force people on the positive list above to
get notifications even though they don&#39;t currently have a
subscription. This could be a <code>-force:boolean</code> parameter
which works in conjunction with the positive list, so that people
on the positive list who aren&#39;t subscribers get a default
email/instant subscription automatically. They can then go back and
change their delivery method and frequency later.</li>
</ol>
<h2>Workflow API</h2>
<h3>API for Defining Workflows</h3>
<p>You can define it using a Tcl interface:</p>
<pre class="code">
set workflow_id [workflow::new \
    -short_name "bug"
    -pretty_name "Bug" \
    -object_id [package::object_id "bug-tracker"] \
    -object_type "bt_bug" \
    -callbacks { bug-tracker.FormatLogTitle } 

#####
#
# Roles
#
#####

workflow::role::add $workflow_id \
    -short_name "submitter" \
    -pretty_name "Submitter" \
    -callbacks { workflow.CreationUser }

workflow::role::add $workflow_id \
    -short_name "assignee" \
    -pretty_name "Assignee" \
    -callbacks {
                bug-tracker.ComponentMaintainer
                bug-tracker.ProjectMaintainer
            }

#####
#
# States
#
#####

workflow::fsm::state::add $workflow_id \
    -short_name "open" \
    -pretty_name "Open" \
    
workflow::fsm::state::add $workflow_id \
    -short_name "resolved" \
    -pretty_name "Resolved"
    
workflow::fsm::state::add $workflow_id \
    -short_name "closed" \
    -pretty_name "Closed"

#####
#
# Actions
#
#####

workflow::fsm::action::add $workflow_id \
    -short_name "comment" \
    -pretty_name "Comment" \
    -pretty_past_tense "Commented" \
    -allowed_roles { submitter assignee } \
    -privileges { feedback }

workflow::fsm::action::add $workflow_id \
    -short_name "edit" \
    -pretty_name "Edit" \
    -pretty_past_tense "Edited" \
    -allowed_roles { submitter assignee } \
    -privileges { write }

workflow::fsm::action::add $workflow_id \
    -short_name "resolve" \
    -pretty_name "Resolve" \
    -pretty_past_tense "Resolved" \
    -assigned_roles { assignee } \
    -enabled_states { open resolved } \
    -new_state "resolved" \
    -privileges { write } \
    -callbacks { bug-tracker.CaptureResolutionCode }

workflow::fsm::action::add $workflow_id \
    -short_name "close" \
    -pretty_name "Close" \
    -pretty_past_tense "Closed" \
    -assigned_roles { submitter } \
    -enabled_states { resolved } \
    -new_state "closed" \
    -privileges { write }

workflow::fsm::action::add $workflow_id \
    -short_name "reopen" \
    -pretty_name "Reopen" \
    -pretty_past_tense "Closed" \
    -allowed_roles { submitter } \
    -enabled_states { resolved closed } \
    -new_state "open" \
    -privileges { write }
</pre>
<p>Alternatively, we could have an ad_form/ad_page_contract style
spec as well:</p>
<pre class="code">
set workflow {
     roles {
         submitter {
             pretty_name "Submitter"
             callbacks { 
                 workflow.CreationUser 
             }
         }
         assignee {
             pretty_name "Assignee"
             callbacks {
                 bug-tracker.ComponentMaintainer
                 bug-tracker.ProjectMaintainer
             }
         }
     }
     states {
         open {
             pretty_name "Open"
         }
         resolved {
             pretty_name "Resolved"
         }
         closed {
             pretty_name "Closed"
         }
     }
     actions {
         comment {
             pretty_name "Comment"
             pretty_past_tense "Commented"
             allowed_roles { submitter assignee }
             privileges { feedback }
         }
         edit {
             pretty_name "Edit"
             pretty_past_tense "Edited"
             allowed_roles { submitter assignee }
             privileges { write }
         }
         resolve {
             pretty_name "Resolve"
             pretty_past_tense "Resolved"
             assigned_roles { assignee }
             enabled_states { open resolved }
             new_state "resolved"
             privileges { write }
             callbacks { bug-tracker.CaptureResolutionCode }
         }
         close {
             pretty_name "Close"
             pretty_past_tense "Closed"
             assigned_roles { submitter }
             enabled_states { resolved }
             new_state "closed"
             privileges { write }
         }
         reopen {
             pretty_name "Reopen"
             pretty_past_tense "Closed"
             allowed_roles { submitter }
             enabled_states { resolved closed }
             new_state "open"
             privileges { write }
         }
     }
 }

set workflow_id [workflow::new \
    -short_name "bug" \
    -pretty_name "Bug" \
    -object_id [package::object_id "bug-tracker"] \
    -object_type "bt_bug" \
    -callbacks { bug-tracker.FormatLogTitle } \
    -workflow $workflow]
</pre>
<h3>API for Starting a Case</h3>
<pre class="code">
set bug_id [bug_tracker::bug::new ...]

workflow::case::new \
    -workflow_id [workflow::get_id -object_id [ad_conn package_id] -short_name "bug"] \
    -object_id $bug_id
</pre>
<h3>API for the Form Page</h3>
<p>The intended user interface for a workflow-based application is
similar to the bug-tracker. The form is shown in display-only mode,
with buttons corresponding to actions along the bottom (e.g.
Comment, Edit, Resolve, Close).</p>
<dl>
<dt>case::get_case_id(object_id, short_name) -&gt; case_id</dt><dd><p>Find the case_id from object_id and workflow short_name.</p></dd><dt>case::get_user_roles(case_id, user_id) -&gt; { list of roles
}</dt><dd><p>Find out which roles the current user has wrt the current
object.</p></dd><dt>case::get_enabled_actions(case_id, user_id) -&gt; { list of {
label name } }</dt><dd><p>The actions currently enabled in this state.</p></dd><dt>case::get_user_actions(case_id, user_id) -&gt; { list of {
label name } }</dt><dd><p>The enabled actions which the current user has permission to
perform.</p></dd><dt>case::action::get_editable_fields(case_id, action) -&gt; { list
of field names }</dt><dd><p>Which fields should we edit, depending on the current action.
NOTE! We probably won&#39;t be able to support this in the first
version.</p></dd><dt>case::state::get_hidden_fields(case_id) -&gt; { list of field
names }</dt><dd><p>Which fields should we hide, depending on the state. NOTE! We
probably won&#39;t be able to support this in the first
version.</p></dd><dt>case::action::available_p(case_id, user_id, action_id) -&gt;
(boolean)</dt><dd><p>Is this action enabled and allowed for this user?</p></dd><dt>case::action::new_state(case_id, action_id) -&gt;
(state_id)</dt><dd><p>The new state which the case will have after this action has
been performed (if action doesn&#39;t change state, returns the
current state again.</p></dd><dt>case::action::execute(case_id, action_id, comment,
comment_format) -&gt; (state_id)</dt><dd><p>Perform the action, updating the workflow state, etc. This
should be called from inside a db_transaction where the case object
has just been updated.</p></dd>
</dl>
<p>Here&#39;s what the form page would look like:</p>
<pre class="code">
ad_page_contract { ... } {
    bug_id:integer,notnull  
}

# Setup return_url, user_id, etc.
...

# Current action, blank for display mode
set action [form get_action bug]

# Check permissions
workflow::case::require_permission -object_id $bug_id -action $action

# Create the form
form create bug \
    -mode display \
    -actions [workflow::case::get_actions -object_id $object_id -action $action] \
    -cancel_url $return_url

element create ...

# Valid submission: Update
if { [form is_valid bug] } {
    bug_tracker::bug::edit \
        -bug_id $bug_id \
        ...

    ad_returnredirect $return_url
    ad_script_abort
}

# Non-valid submission: Either request or error form
if { ![form is_valid bug] } {
    bug_tracker::bug::get -bug_id $bug_id -array bug

    set bug(status) [workflow::action::new_state -object_id $object_id -action $action]

    # Hide elements that should be hidden
    foreach element [workflow::state::get_hidden_fields -object_id $object_id] {
        element set_properties bug $element -widget hidden
    }
    
    # Set element values
    ...
    # - if [form is_request] then set all
    # - otherwise only set elements in display-mode  

    # Page title, context bar, filters, etc.
    ...
}
</pre>
<h2>Future Extensions</h2>
<ul><li>Implement metadata spec and integrate with that so you can pick
which fields in your form to view/edit/hide depending on state and
action.</li></ul>
<p>Nice-to-haves that aren&#39;t <em>entirely</em> pie-in-the-sky
include:</p>
<ul>
<li>User interface components that can generate a user interface
like bug-tracker&#39;s, i.e. buttons below the form showing the
actions that you can take, the resolution entries, the sub-status
codes, etc.</li><li>Pluggable models, for example, finite-state machines,
petri-nets, dependency graphs. A service-contract-based interface
allows you to plug in a new model.</li><li>Integration with a task-list application to maintain the
user&#39;s one task list (synchronization with Palm, etc.).</li><li>Integration with calendar, so deadlines show up there.</li>
</ul>
<h2>Appendix A. Pluggable Models</h2>
<p>I&#39;ve looked into pluggable models before, and it&#39;s not
too complicated. The trick is that you have four areas where the
generic workflow framework/engine will interface with the plugin
model:</p>
<ul>
<li>All workflow models have some definition of 'state'.
For finite state machines, it&#39;s simply the name of the state,
you&#39;re currently in: The structure here is a value from an
enumeration. A petri net has as its state a list of tokens, each of
which is currently in a particular place. A dependency graph model
has as its state the list of tasks that have been completed. The
workflow engine must provide an API for the pluggable model to
access, manipulate, and store its state, but need not know anything
about the internals of the state or how it&#39;s manipulated.</li><li>All workflow models has some elements that go into its workflow
specification: FSMs have states and transitions; a transition is an
arc from one state to another. Petri nets have places and
transitions, and it has arcs that point from a place to a
transition, or a transition to a state. Dependency graphcs has
tasks and dependencies, where a depency goes from one task to
another task.</li><li>All workflow models has some concept of actions (tasks,
transitions). An action has some precondition for when it&#39;s
enabled, i.e., for when a user can or should perform this action.
This is a function of the state. And actions also cause a
well-defined change to the state, i.e., we move to a different
state, tokens are consumed from some places and produced on others,
etc. This is a function of the state, and also produces a new
state.</li>
</ul>
<p>These are the interaction points between a generic workflow
engine, and its specific model implementations.</p>
<h2>Appendix B. Fix or Rewrite</h2>
<p>Should we discard workflow and rewrite, or should we try to
incrementally improve what&#39;s there?</p>
<p>In general, you should be weary of rewriting if:</p>
<ul>
<li>You have many users of your software who&#39;ll want to
upgrade, because they&#39;ll be annoyed by small changes to how
things work.</li><li>You have a different set of people implementing it the second
time than you had the first time.</li>
</ul>
<p>Neither of these are the case here. We don&#39;t have any
significant users of workflow, and we have access to the same
people (person) who did the original implementation to implement it
again.</p>
<p>Besides, the planned changes are so big that there would be no
code left untouched.</p>
<ul>
<li>Switch to FSMs instead of Petri Nets, which obliviates the
engine and most of the admin UI</li><li>Discard Graphviz for admin UI</li><li>Current UI not using form builder/ad_form</li><li>Current data model not using acs-kernel properly, e.g., a new
workflow is an object type.</li>
</ul>
<p>Hence, we&#39;ve concluded that a rewrite is in fact the most
productive strategy.</p>
