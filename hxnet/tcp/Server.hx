package hxnet.tcp;

import sys.net.Host;
import sys.net.Socket;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import hxnet.interfaces.IFactory;
import hxnet.interfaces.IProtocol;

class Server implements hxnet.interfaces.IServer
{

	public var host(default, null):String;
	public var port(default, null):Int;

	public function new(factory:IFactory, port:Int, ?hostname:String)
	{
		bytes = Bytes.alloc(1024);

		this.factory = factory;
		this.host = (hostname == null ? Host.localhost() : hostname);
		this.port = port;

		listener = new Socket();
		listener.bind(new Host(host), port);
		listener.listen(1);
		listener.setBlocking(false);

		readSockets = [listener];
	}

	public function update()
	{
		var select = Socket.select(readSockets, null, null, 0);
		for (socket in select.read)
		{
			if (socket == listener)
			{
				var client = listener.accept();
				client.setBlocking(false);
				readSockets.push(client);

				var cnx = factory.buildProtocol();
				var connection = new Connection(client);
				client.custom = cnx;
				cnx.makeConnection(connection);
			}
			else
			{
				var cnx:IProtocol = socket.custom;
				var size:Int = 0;

				try
				{
					for (i in 0...bytes.length)
					{
						size = i;
						bytes.set(size, socket.input.readByte());
					}
				}
				catch (e:haxe.io.Eof)
				{
					cnx.loseConnection("disconnected");
					socket.close();
					readSockets.remove(socket);
				}
				catch (e:haxe.io.Error)
				{
					// End of stream
				}

				// if we had data, send it to the protocol
				if (size > 0 && cnx != null)
				{
					cnx.dataReceived(new BytesInput(bytes, 0, size));
				}
			}
		}
	}

	public function close()
	{
		listener.close();
	}

	private var factory:IFactory;
	private var readSockets:Array<Socket>;
	private var listener:Socket;

	private var bytes:Bytes;

}
