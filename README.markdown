Declarative Autonaming!
================================

Features Summary
----------------

- Automatically name objects using formats not previously possible without writing Apex Triggers
- Define autonaming rules using standard UI declaratively, no coding required
- Initial implementations based on Andy Fawcett's [Declarative Lookup Rollup Summary Tool](https://github.com/afawcett/declarative-lookup-rollup-summaries) and the [Nonprofit Starter Pack](https://github.com/SalesforceFoundation/Cumulus)
- Open source, available in code and managed package form.
- Supports Custom Metadata, autonaming rules can be included in Change Sets and Packages for easier deployment


Quick Start
-----------
Once you've installed the package, use the Autonaming Rules tab to create a naming rule
<img src="http://media.screensteps.me/bbc-christian/hf4mkx/define-a-naming-rule.png?1464712517"/>
and see it in action
<img src="http://media.screensteps.me/bbc-christian/hf4mkx/see-your-rule-work.png?1464712518"/>

You'll need to give your rule both a name and a unique name the unique name needs to be a) unique and b) formatted_like_this.

Then, enter the API Name of the Object you want autonaming to apply to, and the API name of the field you would like to populate (usually just "Name").

Leave the NameSpec Processor as is, and tick the active box, which just leaves the NameSpec (see below).

Hit Manage Child Trigger, and then Deploy! After that, any edit to an object of your type will cause an auto rename.

NameSpec
--------
The default NameSpec Processor, `DAN_NameSpec` is based on the [Nonprofit Starter Pack](http://github.com/SalesforceFoundation/Cumulus) Opportunity Naming Engine. The format uses full API names and is roughly like merge fields. `{!FieldName__c} - {!OtherObject__r.Field__c}`. Anything not in `{!}` tags will get printed verbatim. Dates and Currencies will be automatically formatted to your locale.

Edits to the NameSpec do not require you to redeploy the trigger. They will just exist for all saves going forward. Batch updating is on the roadmap (safe harbor).

Future Features
---------------
This is very alpha software right now, but my next big feature will hopefully be filtering which objects get renamed/allowing multiple rules per object.


Implementation Considerations
-----------------------------

- **Check Existing Apex Tests.** This tool dynamically deploys Apex Triggers and Apex tests, please make sure your Sandbox and Production org tests are all fully working before you attempt to use this tool. Otherwise usage of this tool will be blocked until you resolve such errors. If your org has triggers or processes on the autonamed SObject, be sure to test your installation in a Sandbox.
- **Existing Tests on Objects**. This tool will update the name field on your objects when it senses activity on namespec fields. Ensure any Apex Triggers you have written on your objects are written with best practices around bulkification in mind. If in doubt be sure to perform significant testing.

Installing the Source Code (Developers)
=======================================

If you are a developer obtain the source code from this repository if you wish to develop it further and/or contribute to it. Click the button below to deploy the source code to your developer or sandbox org.

<a href="https://githubsfdeploy.herokuapp.com?owner=cdcarter&repo=declarative-autonaming">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png">
</a>
