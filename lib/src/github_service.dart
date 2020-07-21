import 'dart:async';
import 'dart:io';

import 'package:desktop/src/private_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

enum AuthState { not_signed_in, signed_in }

class GithubService {
  final _authorizationEndpoint =
      Uri.parse('https://github.com/login/oauth/authorize');
  final _tokenEndpoint =
      Uri.parse('https://github.com/login/oauth/access_token');

  HttpServer _redirectServer;
  http.Client _authenticatedHttpClient;
  StreamController _controller = StreamController<AuthState>();

  Stream<AuthState> get authStream => _controller.stream;

  GithubService() {
    _controller.add(AuthState.not_signed_in);
  }

  Future<void> authenticate() async {
    // Bind to an ephemeral port on localhost
    _redirectServer = await HttpServer.bind('localhost', 0);
    _authenticatedHttpClient = await _getOAuth2Client(
        Uri.parse('http://localhost:${_redirectServer.port}/auth'));
    _controller.add(AuthState.signed_in);
  }

  Future<String> requestUserDetails() async {
    final response =
        await _authenticatedHttpClient.get('https://api.github.com/user');
    return response.body;
  }

  Future<oauth2.Client> _getOAuth2Client(Uri redirectUrl) async {
    var grant = oauth2.AuthorizationCodeGrant(
      githubClientId,
      _authorizationEndpoint,
      _tokenEndpoint,
      secret: githubClientSecret,
      httpClient: _JsonAcceptingHttpClient(),
    );
    var authorizationUrl =
        grant.getAuthorizationUrl(redirectUrl, scopes: githubScopes);

    await _redirect(authorizationUrl);
    var responseQueryParameters = await _listen();
    var client =
        await grant.handleAuthorizationResponse(responseQueryParameters);
    return client;
  }

  Future<void> closeServer() async {
    await _redirectServer?.close();
  }

  Future<void> _redirect(Uri authorizationUrl) async {
    var url = authorizationUrl.toString();
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw GithubLoginException('Could not launch $url');
    }
  }

  Future<Map<String, String>> _listen() async {
    var request = await _redirectServer.first;
    var params = request.uri.queryParameters;
    request.response.statusCode = 200;
    request.response.headers.set('content-type', 'text/plain');
    request.response.writeln('Authenticated! You can close this tab.');
    await request.response.close();
    await _redirectServer.close();
    _redirectServer = null;
    return params;
  }
}

class _JsonAcceptingHttpClient extends http.BaseClient {
  final _httpClient = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return _httpClient.send(request);
  }
}

class GithubLoginException implements Exception {
  const GithubLoginException(this.message);
  final String message;
  @override
  String toString() => message;
}
