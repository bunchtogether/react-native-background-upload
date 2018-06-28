// @flow

declare module "http" {
  declare class Server extends net$Server {
    listen(port: number, hostname?: string, backlog?: number, callback?: Function): Server;
    listen(path: string, callback?: Function): Server;
    listen(handle: Object, callback?: Function): Server;
    close(callback?: (error: ?Error) => mixed): Server;
    maxHeadersCount: number;
    setTimeout(msecs: number, callback: Function): Server;
    timeout: number;
  }

  declare class ClientRequest extends http$ClientRequest {}
  declare class IncomingMessage extends http$IncomingMessage {}
  declare class ServerResponse extends http$ServerResponse {}

  declare function createServer(
    requestListener?: (request: IncomingMessage, response: ServerResponse) => void
  ): Server;
  declare function request(
    options: Object | string,
    callback?: (response: IncomingMessage) => void
  ): ClientRequest;
  declare function get(
    options: Object | string,
    callback?: (response: IncomingMessage) => void
  ): ClientRequest;
}