import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obtainium/components/generated_form_modal.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/main.dart';
import 'package:obtainium/pages/settings.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/source_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

class AppPage extends StatefulWidget {
  const AppPage({super.key, required this.appId});

  final String appId;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  AppInMemory? prevApp;

  @override
  Widget build(BuildContext context) {
    var appsProvider = context.watch<AppsProvider>();
    var settingsProvider = context.watch<SettingsProvider>();
    getUpdate(String id) {
      appsProvider.checkUpdate(id).catchError((e) {
        showError(e, context);
      });
    }

    var sourceProvider = SourceProvider();
    AppInMemory? app = appsProvider.apps[widget.appId];
    var source = app != null ? sourceProvider.getSource(app.app.url) : null;
    if (!appsProvider.areDownloadsRunning() && prevApp == null && app != null) {
      prevApp = app;
      getUpdate(app.app.id);
    }
    var trackOnly = app?.app.additionalSettings['trackOnly'] == true;

    var infoColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
            onTap: () {
              if (app?.app.url != null) {
                launchUrlString(app?.app.url ?? '',
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              app?.app.url ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  decoration: TextDecoration.underline,
                  fontStyle: FontStyle.italic,
                  fontSize: 12),
            )),
        const SizedBox(
          height: 32,
        ),
        Text(
          tr('latestVersionX', args: [app?.app.latestVersion ?? tr('unknown')]),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '${tr('installedVersionX', args: [
                app?.app.installedVersion ?? tr('none')
              ])}${trackOnly ? ' ${tr('estimateInBrackets')}\n\n${tr('xIsTrackOnly', args: [
                  tr('app')
                ])}' : ''}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(
          height: 32,
        ),
        Text(
          tr('lastUpdateCheckX', args: [
            app?.app.lastUpdateCheck == null
                ? tr('never')
                : '\n${app?.app.lastUpdateCheck?.toLocal()}'
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
        ),
        const SizedBox(
          height: 48,
        ),
        CategoryEditorSelector(
            alignment: WrapAlignment.center,
            preselected:
                app?.app.categories != null ? app!.app.categories.toSet() : {},
            onSelected: (categories) {
              if (app != null) {
                app.app.categories = categories;
                appsProvider.saveApps([app.app]);
              }
            }),
      ],
    );

    var fullInfoColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 125),
        app?.installedInfo != null
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.memory(
                  app!.installedInfo!.icon!,
                  height: 150,
                  gaplessPlayback: true,
                )
              ])
            : Container(),
        const SizedBox(
          height: 25,
        ),
        Text(
          app?.installedInfo?.name ?? app?.app.name ?? tr('app'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        Text(
          tr('byX', args: [app?.app.author ?? tr('unknown')]),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          app?.app.id ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        app?.app.releaseDate == null
            ? const SizedBox.shrink()
            : Text(
                app!.app.releaseDate.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
        const SizedBox(
          height: 32,
        ),
        infoColumn,
        const SizedBox(height: 150)
      ],
    );

    return Scaffold(
      appBar: settingsProvider.showAppWebpage ? AppBar() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
          child: settingsProvider.showAppWebpage
              ? app != null
                  ? WebViewWidget(
                      controller: WebViewController()
                        ..setJavaScriptMode(JavaScriptMode.unrestricted)
                        ..setBackgroundColor(
                            Theme.of(context).colorScheme.background)
                        ..setJavaScriptMode(JavaScriptMode.unrestricted)
                        ..setNavigationDelegate(
                          NavigationDelegate(
                            onWebResourceError: (WebResourceError error) {
                              if (error.isForMainFrame == true) {
                                showError(
                                    ObtainiumError(error.description,
                                        unexpected: true),
                                    context);
                              }
                            },
                          ),
                        )
                        ..loadRequest(Uri.parse(app.app.url)))
                  : Container()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: Column(children: [fullInfoColumn])),
                  ],
                ),
          onRefresh: () async {
            if (app != null) {
              getUpdate(app.app.id);
            }
          }),
      bottomSheet: Padding(
          padding: EdgeInsets.fromLTRB(
              0, 0, 0, MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (app?.app.additionalSettings['versionDetection'] !=
                                'standardVersionDetection' &&
                            !trackOnly &&
                            app?.app.installedVersion != null &&
                            app?.app.installedVersion != app?.app.latestVersion)
                          IconButton(
                              onPressed: app?.downloadProgress != null
                                  ? null
                                  : () {
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext ctx) {
                                            return AlertDialog(
                                              title: Text(tr(
                                                  'alreadyUpToDateQuestion')),
                                              actions: [
                                                TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: Text(tr('no'))),
                                                TextButton(
                                                    onPressed: () {
                                                      HapticFeedback
                                                          .selectionClick();
                                                      var updatedApp = app?.app;
                                                      if (updatedApp != null) {
                                                        updatedApp
                                                                .installedVersion =
                                                            updatedApp
                                                                .latestVersion;
                                                        appsProvider.saveApps(
                                                            [updatedApp]);
                                                      }
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: Text(
                                                        tr('yesMarkUpdated')))
                                              ],
                                            );
                                          });
                                    },
                              tooltip: tr('markUpdated'),
                              icon: const Icon(Icons.done)),
                        if (source != null &&
                            source
                                .combinedAppSpecificSettingFormItems.isNotEmpty)
                          IconButton(
                              onPressed: app?.downloadProgress != null
                                  ? null
                                  : () {
                                      showDialog<Map<String, dynamic>?>(
                                          context: context,
                                          builder: (BuildContext ctx) {
                                            var items = source
                                                .combinedAppSpecificSettingFormItems
                                                .map((row) {
                                              row.map((e) {
                                                if (app?.app.additionalSettings[
                                                        e.key] !=
                                                    null) {
                                                  e.defaultValue = app?.app
                                                          .additionalSettings[
                                                      e.key];
                                                }
                                                return e;
                                              }).toList();
                                              return row;
                                            }).toList();
                                            return GeneratedFormModal(
                                              title: tr('additionalOptions'),
                                              items: items,
                                            );
                                          }).then((values) {
                                        if (app != null && values != null) {
                                          Map<String, dynamic>
                                              originalSettings =
                                              app.app.additionalSettings;
                                          app.app.additionalSettings = values;
                                          if (source.enforceTrackOnly) {
                                            app.app.additionalSettings[
                                                'trackOnly'] = true;
                                            showError(
                                                tr('appsFromSourceAreTrackOnly'),
                                                context);
                                          }
                                          if (app.app.additionalSettings[
                                                  'versionDetection'] ==
                                              'releaseDateAsVersion') {
                                            if (originalSettings[
                                                    'versionDetection'] !=
                                                'releaseDateAsVersion') {
                                              if (app.app.releaseDate != null) {
                                                bool isUpdated =
                                                    app.app.installedVersion ==
                                                        app.app.latestVersion;
                                                app.app.latestVersion = app
                                                    .app
                                                    .releaseDate!
                                                    .microsecondsSinceEpoch
                                                    .toString();
                                                if (isUpdated) {
                                                  app.app.installedVersion =
                                                      app.app.latestVersion;
                                                }
                                              }
                                            }
                                          } else if (originalSettings[
                                                  'versionDetection'] ==
                                              'releaseDateAsVersion') {
                                            app.app.installedVersion = app
                                                    .installedInfo
                                                    ?.versionName ??
                                                app.app.installedVersion;
                                          }
                                          appsProvider.saveApps([app.app]).then(
                                              (value) {
                                            getUpdate(app.app.id);
                                          });
                                        }
                                      });
                                    },
                              tooltip: tr('additionalOptions'),
                              icon: const Icon(Icons.edit)),
                        if (app != null && app.installedInfo != null)
                          IconButton(
                            onPressed: () {
                              appsProvider.openAppSettings(app.app.id);
                            },
                            icon: const Icon(Icons.settings),
                            tooltip: tr('settings'),
                          ),
                        if (app != null && settingsProvider.showAppWebpage)
                          IconButton(
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext ctx) {
                                      return AlertDialog(
                                        scrollable: true,
                                        content: infoColumn,
                                        title: Text(
                                            '${app.app.name} ${tr('byX', args: [
                                              app.app.author
                                            ])}'),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(tr('continue')))
                                        ],
                                      );
                                    });
                              },
                              icon: const Icon(Icons.more_horiz),
                              tooltip: tr('more')),
                        const SizedBox(width: 16.0),
                        Expanded(
                            child: TextButton(
                                onPressed: (app?.app.installedVersion == null ||
                                            app?.app.installedVersion !=
                                                app?.app.latestVersion) &&
                                        !appsProvider.areDownloadsRunning()
                                    ? () {
                                        HapticFeedback.heavyImpact();
                                        () async {
                                          if (app?.app.additionalSettings[
                                                  'trackOnly'] !=
                                              true) {
                                            await settingsProvider
                                                .getInstallPermission();
                                          }
                                        }()
                                            .then((value) {
                                          appsProvider
                                              .downloadAndInstallLatestApps(
                                                  [app!.app.id],
                                                  globalNavigatorKey
                                                      .currentContext).then(
                                                  (res) {
                                            if (res.isNotEmpty && mounted) {
                                              Navigator.of(context).pop();
                                            }
                                          }).catchError((e) {
                                            showError(e, context);
                                          });
                                        }).catchError((e) {
                                          showError(e, context);
                                        });
                                      }
                                    : null,
                                child: Text(app?.app.installedVersion == null
                                    ? !trackOnly
                                        ? tr('install')
                                        : tr('markInstalled')
                                    : !trackOnly
                                        ? tr('update')
                                        : tr('markUpdated')))),
                        const SizedBox(width: 16.0),
                        Expanded(
                            child: TextButton(
                          onPressed: app?.downloadProgress != null
                              ? null
                              : () {
                                  appsProvider.removeAppsWithModal(
                                      context, [app!.app]).then((value) {
                                    if (value == true) {
                                      Navigator.of(context).pop();
                                    }
                                  });
                                },
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              surfaceTintColor:
                                  Theme.of(context).colorScheme.error),
                          child: Text(tr('remove')),
                        )),
                      ])),
              if (app?.downloadProgress != null)
                Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    child: LinearProgressIndicator(
                        value: app!.downloadProgress! / 100))
            ],
          )),
    );
  }
}
