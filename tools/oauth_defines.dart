// Turns the OAuth client files downloaded from the Google Cloud console into the build-time defines the app
// reads (see lib/core/auth/oauth_config.dart).
//
//   dart run tools/oauth_defines.dart [secrets-dir]
//
// Reads  <secrets-dir>/desktop_client.json   (the "Desktop app" client, as downloaded)
//        <secrets-dir>/web_client.txt        (the "Web application" client id, one line; optional)
// Writes <secrets-dir>/dart_defines.json     (git-ignored, with the rest of app/secrets/)
//
// Then run or build the app with:  flutter run --dart-define-from-file=secrets/dart_defines.json
// No secret value is printed.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) => exit(run(args));

int run(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent;
  final dir = Directory(args.isNotEmpty ? args.first : '${root.path}/app/secrets');

  final defines = <String, String>{};

  final desktop = File('${dir.path}/desktop_client.json');
  if (desktop.existsSync()) {
    final json = jsonDecode(desktop.readAsStringSync()) as Map<String, dynamic>;
    // A "Desktop app" client downloads as {"installed": {...}}; a "Web application" one as {"web": {...}}.
    final client = json['installed'] as Map<String, dynamic>?;
    if (client == null) {
      stderr.writeln(
        'desktop_client.json is not a "Desktop app" client (it has no "installed" section). '
        'The Windows build needs one; the Web client id goes in web_client.txt.',
      );
      return 1;
    }
    final id = client['client_id'] as String?;
    final secret = client['client_secret'] as String?;
    if (id == null || id.isEmpty) {
      stderr.writeln('desktop_client.json has no client_id. Download the "Desktop app" client again.');
      return 1;
    }
    defines['DESKTOP_CLIENT_ID'] = id;
    defines['DESKTOP_CLIENT_SECRET'] = secret ?? '';
  } else {
    stderr.writeln('Note: ${desktop.path} not found; the Windows sign-in will say it is not configured.');
  }

  final web = File('${dir.path}/web_client.txt');
  if (web.existsSync()) {
    final id = web.readAsStringSync().trim();
    if (id.isNotEmpty) defines['WEB_CLIENT_ID'] = id;
  } else {
    stderr.writeln('Note: ${web.path} not found; Android sign-in may need it as serverClientId.');
  }

  if (defines.isEmpty) {
    stderr.writeln('Nothing to write: no client files found in ${dir.path}.');
    return 1;
  }

  File('${dir.path}/dart_defines.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(defines));
  stdout.writeln('Wrote ${dir.path}/dart_defines.json with: ${defines.keys.join(', ')}');
  return 0;
}
