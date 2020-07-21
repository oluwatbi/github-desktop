import 'package:desktop/src/github_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => GithubService(),
      child: MaterialApp(
        title: 'GitHub GraphQL API Client',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage(title: 'GitHub GraphQL API Client'),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder(
          stream: context.watch<GithubService>().authStream,
          builder: (context, snapshot) {
            if (snapshot == null ||
                snapshot.error != null ||
                !snapshot.hasData) {
              return Container();
            }
            if (snapshot.data == AuthState.signed_in) {
              return Main();
            }
            return Login();
          }),
    );
  }
}

class Main extends StatelessWidget {
  const Main({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FutureBuilder<String>(
      future: context.watch<GithubService>().requestUserDetails(),
      builder: (context, snapshot) {
        if (snapshot == null || snapshot.error != null || !snapshot.hasData) {
          return Container();
        }
        return Text(
          snapshot.data,
        );
      },
    ));
  }
}

class Login extends StatelessWidget {
  const Login({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RaisedButton(
        onPressed: () async {
          final githubService = context.read<GithubService>();
          githubService.authenticate();
        },
        child: const Text('Login to Github'),
      ),
    );
  }
}
