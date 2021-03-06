// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  CredentialsProvider+getAssumedCredentials.swift
//  SmokeAWSCredentials
//

import Foundation
import SmokeAWSCore
import SecurityTokenClient
import SmokeHTTPClient
import LoggerAPI

public extension SmokeAWSCore.CredentialsProvider {
    
    /**
     Function to get assumed role credentials that will not track expiration and rotate.
 
     - Parameters:
        - roleArn: the ARN of the role that is to be assumed.
        - roleSessionName: the session name to use when assuming the role.
        - retryConfiguration: the client retry configuration to use to get the credentials.
                              If not present, the default configuration will be used.
     */
    public func getAssumedStaticCredentials(
            roleArn: String,
            roleSessionName: String,
            retryConfiguration: HTTPClientRetryConfiguration = .default) -> StaticCredentials? {
        return AWSSecurityTokenClient.getAssumedStaticCredentials(
            roleArn: roleArn,
            roleSessionName: roleSessionName,
            credentialsProvider: self,
            retryConfiguration: retryConfiguration)
    }
    
    /**
     Function to get assumed role credentials that will track expiration and rotate.
 
     - Parameters:
        - roleArn: the ARN of the role that is to be assumed.
        - roleSessionName: the session name to use when assuming the role.
        - durationSeconds: The duration, in seconds, of the role session. The value can
            range from 900 seconds (15 minutes) to 3600 seconds (1 hour). By default, the value
            is set to 3600 seconds.
        - retryConfiguration: the client retry configuration to use to get the credentials.
                              If not present, the default configuration will be used.
     */
    public func getAssumedRotatingCredentials(
        roleArn: String,
        roleSessionName: String,
        durationSeconds: Int?,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        eventLoopProvider: HTTPClient.EventLoopProvider = .spawnNewThreads) -> StoppableCredentialsProvider? {
        return AWSSecurityTokenClient.getAssumedRotatingCredentials(
            roleArn: roleArn,
            roleSessionName: roleSessionName,
            credentialsProvider: self,
            durationSeconds: durationSeconds,
            retryConfiguration: retryConfiguration,
            eventLoopProvider: eventLoopProvider)
    }
}
