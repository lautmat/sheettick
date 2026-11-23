import 'package:googleapis/drive/v3.dart' show DetailedApiRequestError;
import 'package:googleapis_auth/googleapis_auth.dart' show AccessDeniedException;

import '../auth/auth_service.dart' show AuthException;
import '../sheets/bootstrap.dart';

/// The sign-in no longer works: the access was revoked or withdrawn (as opposed to a network or server problem). A 403
/// is deliberately not included: Google also uses it for rate limits and for an API that is not enabled in the Cloud
/// project, and signing the user out would not fix either.
bool isAuthFailure(Object e) =>
    e is AccessDeniedException || e is AuthException || (e is DetailedApiRequestError && e.status == 401);

/// A problem with the spreadsheet itself that trying again will not fix: it was deleted, or its layout is not one this
/// version understands. The user has to do something, and the app says what when it is opened.
bool isBlockedBySpreadsheet(Object e) =>
    e is SpreadsheetMissingException || e is SchemaTooNewException || e is SchemaMismatchException;
