import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  const port = 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Server running on http://localhost:$port');

  await for (final request in server) {
    await handleRequest(request);
  }
}

Future<void> handleRequest(HttpRequest request) async {
  var path = request.uri.path;
  if (path == '/') path = '/index.html';

  final file = File('build/web$path');

  if (await file.exists()) {
    final content = await file.readAsBytes();
    final ext = p.extension(path).toLowerCase();
    final contentType = _getContentType(ext);
    request.response.headers.contentType = contentType;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.add(content);
    await request.response.close();
  } else {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('404 Not Found: $path');
    await request.response.close();
  }
}

ContentType _getContentType(String ext) {
  switch (ext) {
    case '.html': return ContentType.html;
    case '.js': return ContentType('application', 'javascript');
    case '.css': return ContentType('text', 'css');
    case '.json': return ContentType.json;
    case '.png': return ContentType('image', 'png');
    case '.jpg':
    case '.jpeg': return ContentType('image', 'jpeg');
    case '.gif': return ContentType('image', 'gif');
    case '.svg': return ContentType('image', 'svg+xml');
    case '.ico': return ContentType('image', 'x-icon');
    case '.woff': return ContentType('font', 'woff');
    case '.woff2': return ContentType('font', 'woff2');
    case '.ttf': return ContentType('font', 'ttf');
    case '.otf': return ContentType('font', 'otf');
    case '.txt': return ContentType.text;
    default: return ContentType.binary;
  }
}
