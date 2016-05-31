Declarative Autonaming!
================================

Features Summary
----------------

- Automatically name objects using formats not previously possible without writing Apex Triggers
- Define autonaming rules using standard UI declaratively, no coding required
- Initial implementations based on Andy Fawcett's [Declarative Lookup Rollup Summary Tool](https://github.com/afawcett/declarative-lookup-rollup-summaries) and the [Nonprofit Starter Pack](https://github.com/SalesforceFoundation/Cumulus)
- Open source, available in code and managed package form.
- Supports Custom Metadata, autonaming rules can be included in Change Sets and Packages for easier deployment


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