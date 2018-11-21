// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//  BasicChannelInboundHandler.swift
//  SmokeAWSCredentials
//

import Foundation
import NIO
import NIOHTTP1
import LoggerAPI

enum BasicHttpChannelError: Error {
    case invalidEndpoint(String)
    case badResponse(String)
    case errorResponse(UInt, String?)
    case noResponse
}

/**
 A basic ChannelInboundHandler for contacting an endpoint and
 returning the response as a Data instance.
 */
final class BasicChannelInboundHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart
    
    /// The endpoint path to request a response from.
    private let endpointPath: String
    private let endpointHostName: String
    
    /// The http head of the response received
    private var responseHead: HTTPResponseHead?
    /// The list of previous body ByteBuffers received.
    private var bodyParts: [ByteBuffer] = []
    
    init(endpointHostName: String, endpointPath: String) {
        self.endpointHostName = endpointHostName
        self.endpointPath = endpointPath
    }
    
    static func call(endpointHostName: String,
                     endpointPath: String,
                     endpointPort: Int = 80) throws -> Data? {
        let handler = BasicChannelInboundHandler(endpointHostName: endpointHostName,
                                                 endpointPath: endpointPath)
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            // shut down the event loop group when we are done
            // (as this function will block until the request is complete)
            do {
                try eventLoopGroup.syncShutdownGracefully()
            } catch {
                Log.debug("Unable to shut down event loop group: \(error)")
            }
        }
        
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().then {
                    channel.pipeline.add(handler: handler)
                }
            }
        
        let channel = try bootstrap.connect(host: endpointHostName, port: endpointPort).wait()
        
        // wait until the channel has been closed
        try channel.closeFuture.wait()
        
        // retrieve the response from the handler
        return try handler.getResponse()
    }
    
    /**
     Called when data has been received from the channel.
     */
    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        Log.verbose("channelRead")
        let responsePart = self.unwrapInboundIn(data)
        
        switch responsePart {
        // This is the response head
        case .head(let request):
            Log.verbose("channelRead: head")
            responseHead = request
        // This is part of the response body
        case .body(let byteBuffer):
            Log.verbose("channelRead: body")
            // store this part of the body
            bodyParts.append(byteBuffer)
        // This is the response end
        case .end:
            Log.verbose("channelRead: end")
            // the head and all possible body parts have been received,
            // handle this response
            ctx.close(promise: nil)
        }
    }
    
    func channelReadComplete(ctx: ChannelHandlerContext) {
        Log.verbose("channelReadComplete")
    }
    
    /*
     Gets the response from the handler
     */
    public func getResponse() throws -> Data? {
        // concatenate any parts into a single byte array
        let bodyBytes: [UInt8] = bodyParts.reduce([]) { (partialBytes, part) in
            let partBytes = part.getBytes(at: 0, length: part.readableBytes)
            
            if let partBytes = partBytes {
                return partialBytes + partBytes
            } else {
                return partialBytes
            }
        }
        
        let responseBodyData = !bodyBytes.isEmpty ? Data(bytes: bodyBytes) : nil
        
        // ensure the response head from received
        guard let responseHead = responseHead else {
            throw BasicHttpChannelError.badResponse("Response head was not received")
        }
        
        // if the response status is ok
        if case .ok = responseHead.status {
            // return the response data (potentially empty)
            return responseBodyData
        }
        
        let bodyAsString: String?
        if let responseBodyData = responseBodyData {
            bodyAsString = String(data: responseBodyData, encoding: .utf8)
        } else {
            bodyAsString = nil
        }
        
        throw BasicHttpChannelError.errorResponse(responseHead.status.code, bodyAsString)
    }
    
    /**
     Called when notifying about a connection error.
     */
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        Log.verbose("Error received from HTTP connection: \(String(describing: error))")
        
        // close the channel
        ctx.close(promise: nil)
    }
    
    /**
     Called when the channel becomes active.
     */
    public func channelActive(ctx: ChannelHandlerContext) {
        Log.verbose("channelActive")
        let headers = [("User-Agent", "SmokeAWSCredentials"),
                       ("Content-Length", "0"),
                       ("Host", endpointHostName),
                       ("Accept", "*/*")]
        
        // Create the request head
        var httpRequestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                              method: .GET, uri: endpointPath)
        httpRequestHead.headers = HTTPHeaders(headers)
        
        // Send the request on the channel.
        ctx.write(self.wrapOutboundOut(.head(httpRequestHead)), promise: nil)
        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
