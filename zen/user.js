// Zen's prefs, applied over prefs.js at every start: a pref set here can't be changed for good in
// about:config. Taking a line out doesn't undo it either; reset it in about:config after.
// zen/link puts this in Zen's default profile.

// Read chrome/userChrome.css and userContent.css (the theme's, from retheme)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Disable telemetry
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

// Disable Normandy (remote experiments/studies)
user_pref("app.normandy.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);

// Disable crash reporting
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// Disable coverage/beacon
user_pref("toolkit.coverage.opt-out", true);
user_pref("beacon.enabled", false);
