# Developing
# RT  plugin
# for fun and profit
## (mostly for profit) <!-- .element: class="fragment" data-fragment-index="1" -->

---

## Internet is a magical sphere...

---

<img style="border: 0; height: 100%; width: 100%;" src="../img/magical-sphere-2.jpg"/>

Note:
Back in 2008 when I worked as a system administrator I needed a way to organize my work...
Somehow I realised that what I need called "time management"...
...And since I was a sysadmin I added "for system administrators" to my query.
...And - surprise!

---

<img style="border: 0; height: 40%; width: 40%;" src="../img/time-management.jpg"/>

Note:
This was The book that made me know about issue tracking software.
Software it mentioned was Request Tracker - ticketing system by Best Practical solutions.
---

## Request Tracker (or RT)

* Open-source request tracking system
* Free for any use
* Developed and supported by Best Practical Solutions, LLC
* Written in Perl

Note:
I've installed it in the organization I worked at and we used it with my colleauge quite successfully.
I played with it and set it up.
But then times changed and I've become a Perl programmer and forgot about RT for ages...
...until I found a contract from one of Moscow ISPs who wanted to improve RT to work with their customer's data.

---

## RT is a ticket system

RT is a battle-tested issue tracking system which thousands of organizations use for bug tracking, help desk ticketing, customer service, workflow processes, change management, network operations, youth counselling and even more. 

Organizations around the world have been running smoothly thanks to RT for over 10 years.

[https://bestpractical.com/rt/](https://bestpractical.com/rt/)

---

## Perl ecosystem uses RT!

<img style="border: 0; height: 100%; width: 100%;" src="../img/rt-cpan.png"/>

---

## RT is a "construction kit"

All your workflow and business logic can be taught to RT using powerful **"scrips"**, **lifecycles**, **custom fields**, **approvals**, and **extensions** which let you spend less time keeping tedious records.

---

## RT basic concepts

* Tickets
* Queues
* Custom Fields (CFs)
* Users
* Groups
* Rights

Note:
*Ticket* can be created in a *Queue*. Each *Queue* can have its own set of associated *CFs*. Custom fields can be created on their own.
We can assign a *right* to access some *queue* to certain *users* or *groups*.

---

## Let's imagine we're at ISP's call center

* Stuff accepts calls, creates tickets and fills CFs with user's information:
  * Contract №, Phone №, First and last name of the user
  * Switch port №, IP address, bandwidth
  * ...etc

---

## Every ticket goes to one of the queues...

* **HELPDESK** - computer-related consultation
* **SUPPORT** - 2nd level support
* **USER** - engineer's presence on user side is required

Every queue has its own set of associated CFs.

---

<img style="border: 0; height: 100%; width: 100%;" src="../img/new-support-ticket.png"/>

---

## Some of CFs are "ID" fields

* **Contract №**, Phone №, First and last name of the user
* **Switch port №**, IP address, bandwidth

---

## Objective

Make it easier to fill user's data: *CF*s, *subject* and *content* of tickets.

Note:
Call center specialists don't have a time to fill some of that stuff I mentioned while on a call: other calls are waiting. Thus they need to be able to press a button and have some data loaded automatically.
---

## How?

* Add *"Get data"* button near every *ID field*, which, when pressed, takes value from *ID field* and fills other CFs with relevant data.
* Make it possible to configure *ID fields* and *data sources*

---

## Development plan

* Display "Get data" button after each of "ID fields"
* Provide API endpoint which:
  * Accepts value of ID field
  * Reads data from preconfigured sources (database, external command output, predefined text)
  * Returns values for *Subject*, *Body* and *non-ID Custom Fields*
* Bind a JavaScript code to "Get data" button, which:
  * Sends value of ID field to the backend
  * Accepts returned values and populates the appropriate fields

---

## Step 0:
## Configuration file format

Note:
We need a configuration for our plugin to:
* Identify key fields
* Specify data sources

Configuration will be in JSON format.

---

## Configuration: key fields

```javascript

"key_fields": {
    // 1 - internal ID of CF in RT
    // __ACCOUNT_ID__ - template to be replaced by the actual value
    "1": "__ACCOUNT_ID__",
    "5": "__SWITCH_ID__"
},
```

---

<img style="border: 0; height: 100%; width: 100%;" src="../img/cfs-to-queue.png"/>

---

## Configuration: databases

```javascript

"databases": {
    "users": {
        "database": "users",
        "type":     "mysql",
        "host":     "localhost",
        "port":     "3306",
        "username": "mysql_user",
        "password": "mysql_password_123"
    }
}
```

---

## Data source: SQL query

```javascript

"field_sources": {
    // 2 - ID of a CF to be populated in RT
    "2": [
        {
            "database": "users",
            "sql" : "SELECT ip
                    FROM ip_address
                    WHERE account_id = __ACCOUNT_ID__"
        }
    ]
}
```

---

## Data source: command output

```javascript

"3": [
    {
        "command": "/bin/echo 'Hello, __ACCOUNT_ID__!'"
    }
]
```

---

## Data source: compound

```javascript

{
    "Body": [
        { "command": "/bin/cat /home/rt/__ACCOUNT_ID__" },
        { "Text": "Hello, user #__ACCOUNT_ID__!" },
    ],
    "Subject": [
        { "command": "/bin/get_subject __ACCOUNT_ID__" }
    ]
}
```

---

## Step 1. Adding a button

---

## RT is built with HTML::Mason

* Mason's various pieces revolve around the notion of "components"
* A component is a mix of HTML, Perl, and special Mason commands, one component per file
* Mason's component syntax lets designers separate a web page into programmatic and design elements

Note:
Mason is such a PHP, but you can write in Perl inside of it ;)
---

## Components

```pre
./Ticket/Graphs:
dhandler Elements index.html

./Ticket/Graphs/Elements:
EditGraphProperties ShowGraph ShowLegends

./User/Elements:
Portlets TicketList UserInfo

./User/Elements/Portlets:
ActiveTickets CreateTicket ExtraInfo InactiveTickets
```

Note:
It might look attractive to find a component which renders Custom Fields and edit it to include the "Get data" button after each of the Key Field according to config. But please DON'T. You don't want to ship your changed files to your customers, you **can't** ship them to the outside world.

---

## RT Callbacks

* RT uses Callbacks for adding extensions into the Web UI without modifying html code

Note:
There is a lot of callbacks inside of RT code.
---

### Path to Callback:

```pre
<rt root>/local/html/Callbacks/<any-directory>/<path-to-component>/
    <CallbackName>
```

---

### Path for Callback from Plugin:

```pre
html/Callbacks/<plugin-name>/<path-to-component>/<Callback name>
```

---

### Callbacks we need


```pre
# Elements/EditCustomFields

$m->callback(
    CallbackName => 'AfterCustomFieldValue',
    CustomField  => $CustomField,
    ...
);
```

---

## "Get data" button

```pre
# html/Callbacks/RTx-FillTicketData/Elements/EditCustomFields/AfterCustomFieldValue

% my $config = RTx::FillTicketData::config();
% if ($CustomField
%   && $config
%   && $config->{key_fields}->{ $CustomField->Id } ) {
    <td class="entry">
      <button class="autofill_custom_fields"><% loc('Get data') %></button>
    </td>
% }
<%ARGS>
    $CustomField => undef
</%ARGS>
```

---

## Static files

```perl
# in lib/RTx/FillTicketData.pm:

# Add plugin-related JavaScript:
RT->AddJavaScript('RTx-FillTicketData.js');

# Can also add CSS:
# RT->AddStyleSheets('...');
```

Note:
A bit later I'll show you directory layout for the plugin to get static files installed properly.
---

## API endpoint

```pre
# html/Helpers/GetTicketData

<%perl>
    $m->out(
        RT::Interface::Web::EncodeJSON(
            RTx::FillTicketData::get_data({ %ARGS })
        )
    );
    $m->abort;
</%perl>

<%init>
    use RT::Interface::Web;
    $r->content_type('application/json');
</%init>
```
---

---

---

---

## A note on plugin naming

* `RT::Extension::$Something`
* `RTx::$Something`

Note:
I started with RT::Extension as it looks like the recommended naming scheme by Best Practical, but got completely annoyed by constantly typing it every time (maybe I should improve my Vim-fu) - `RTx` is so much shorter.
---
### Makefile.PL

```perl
use inc::Module::Install;

# Define module name and directories to install
RTx 'RTx-FillTicketData'; # Module::Install::RTx
requires_rt('4.0.0');

# Abstract, author, version, license, Perl version
all_from('lib/RTx/FillTicketData.pm');
no_index 'etc';

# Write out META.yml and Makefile
WriteAll();
```

---

## Sources of information

* https://bestpractical.com/resources/ - links to various resources including *perldoc for RT*, *forum*, *blog*, *wiki*, and *user guides*.
* Source code of RT itself and its plugins (e.g. [https://metacpan.org/pod/RTx::FillTicketData](https://metacpan.org/pod/RTx::FillTicketData))

---

# Questions?

---

# Thank you!

<br/>
<br/>
<p style="font-size: xx-large;">
Ilya Chesnokov, <a href="mailto:chesnokov@cpan.org">chesnokov@cpan.org</a><br/><br/>
TPC::EU, Amsterdam, 2017
</p>
