# frozen_string_literal: true

#-------------------------------------------------------------------------
# # Copyright (c) Microsoft and contributors. All rights reserved.
#
# The MIT License(MIT)

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files(the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions :

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#--------------------------------------------------------------------------
require "azure/storage/file/serialization"

module Azure::Storage::File
  StorageService = Azure::Storage::Common::Service::StorageService
  module Directory
    include Azure::Storage::Common::Service

    class Directory
      def initialize
        @properties = {}
        @metadata = {}
        yield self if block_given?
      end

      attr_accessor :name
      attr_accessor :properties
      attr_accessor :metadata
    end
  end

  # Public: Get a list of files or directories under the specified share or directory.
  #         It lists the contents only for a single level of the directory hierarchy.
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  #
  # * +:prefix+                  - String. Filters the results to return only directories and files
  #                                whose name begins with the specified prefix. (optional)
  # * +:marker+                  - String. An identifier the specifies the portion of the
  #                                list to be returned. This value comes from the property
  #                                Azure::Storage::Common::EnumerationResults.continuation_token when there
  #                                are more shares available than were returned. The
  #                                marker value may then be used here to request the next set
  #                                of list items. (optional)
  #
  # * +:max_results+             - Integer. Specifies the maximum number of shares to return.
  #                                If max_results is not specified, or is a value greater than
  #                                5,000, the server will return up to 5,000 items. If it is set
  #                                to a value less than or equal to zero, the server will return
  #                                status code 400 (Bad Request). (optional)
  #
  # * +:timeout+                 - Integer. A timeout in seconds.
  #
  # * +:request_id+              - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                in the analytics logs when storage analytics logging is enabled.
  #
  # * +:location_mode+           - LocationMode. Specifies the location mode used to decide 
  #                                which location the request should be sent to.
  #
  # See: https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/list-directories-and-files
  #
  # Returns an Azure::Storage::Common::EnumerationResults
  #
  def list_directories_and_files(share, directory_path, options = {})
    query = { "comp" => "list" }
    unless options.nil?
      StorageService.with_query query, "marker", options[:marker]
      StorageService.with_query query, "maxresults", options[:max_results].to_s if options[:max_results]
      StorageService.with_query query, "timeout", options[:timeout].to_s if options[:timeout]
      StorageService.with_query query, "prefix", options[:prefix].to_s if options[:prefix]
      include = normalize_include_options(options[:include])
      StorageService.with_query query, "include", include if include
    end

    options[:request_location_mode] = Azure::Storage::Common::RequestLocationMode::PRIMARY_OR_SECONDARY
    uri = directory_uri(share, directory_path, query, options)
    response = call(:get, uri, nil, {}, options)

    # Result
    if response.success?
      Serialization.directories_and_files_enumeration_results_from_xml(response.body)
    else
      response.exception
    end
  end

  INCLUDE_OPTIONS = %w[Timestamps ETag Attributes PermissionKey].map { |option| [option.downcase, option] }.to_h

  protected def normalize_include_options(include)
    return if include.nil?
    if include.is_a?(Array)
      INCLUDE_OPTIONS.slice(*include.map { |o| o.to_s.downcase.gsub("_", "") }).values.compact.join(",")
    else
      include.to_s
    end
  end

  # Public: Create a new directory
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:metadata+                 - Hash. User defined metadata for the share (optional).
  # * +:timeout+                  - Integer. A timeout in seconds.
  # * +:request_id+               - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                 in the analytics logs when storage analytics logging is enabled.
  #
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/create-directory
  #
  # Returns a Directory
  def create_directory(share, directory_path, options = {})
    # Query
    query = {}
    query["timeout"] = options[:timeout].to_s if options[:timeout]

    # Scheme + path
    uri = directory_uri(share, directory_path, query)

    # Headers
    headers = {}
    StorageService.add_metadata_to_headers(options[:metadata], headers) if options[:metadata]

    # Call
    response = call(:put, uri, nil, headers, options)

    # result
    directory = Serialization.directory_from_headers(response.headers)
    directory.name = directory_path
    directory.metadata = options[:metadata] if options[:metadata]
    directory
  end

  # Public: Returns all system properties for the specified directory,
  #         and can also be used to check the existence of a directory.
  #         The data returned does not include the files in the directory or any subdirectories.
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:timeout+                  - Integer. A timeout in seconds.
  # * +:request_id+               - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                 in the analytics logs when storage analytics logging is enabled.
  # * +:location_mode+            - LocationMode. Specifies the location mode used to decide 
  #                                 which location the request should be sent to.
  #
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/get-directory-properties
  #
  # Returns a Directory
  def get_directory_properties(share, directory_path, options = {})
    # Query
    query = {}
    query["timeout"] = options[:timeout].to_s if options[:timeout]

    # Call
    options[:request_location_mode] = Azure::Storage::Common::RequestLocationMode::PRIMARY_OR_SECONDARY
    response = call(:get, directory_uri(share, directory_path, query, options), nil, {}, options)

    # result
    directory = Serialization.directory_from_headers(response.headers)
    directory.name = directory_path
    directory
  end

  # Public: Deletes a directory.
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:timeout+                  - Integer. A timeout in seconds.
  # * +:request_id+               - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                 in the analytics logs when storage analytics logging is enabled.
  #
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/delete-directory
  #
  # Returns nil on success
  def delete_directory(share, directory_path, options = {})
    # Query
    query = {}
    query["timeout"] = options[:timeout].to_s if options[:timeout]

    # Call
    call(:delete, directory_uri(share, directory_path, query), nil, {}, options)

    # result
    nil
  end

  # Public: Returns only user-defined metadata for the specified directory.
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:timeout+                  - Integer. A timeout in seconds.
  # * +:request_id+               - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                 in the analytics logs when storage analytics logging is enabled.
  # * +:location_mode+            - LocationMode. Specifies the location mode used to decide 
  #                                 which location the request should be sent to.
  #
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/get-directory-metadata
  #
  # Returns a Directory
  def get_directory_metadata(share, directory_path, options = {})
    # Query
    query = { "comp" => "metadata" }
    query["timeout"] = options[:timeout].to_s if options[:timeout]

    # Call
    options[:request_location_mode] = Azure::Storage::Common::RequestLocationMode::PRIMARY_OR_SECONDARY
    response = call(:get, directory_uri(share, directory_path, query, options), nil, {}, options)

    # result
    directory = Serialization.directory_from_headers(response.headers)
    directory.name = directory_path
    directory
  end

  # Public: Sets custom metadata for the directory.
  #
  # ==== Attributes
  #
  # * +share+                     - String. The name of the file share.
  # * +directory_path+            - String. The path to the directory.
  # * +metadata+                  - Hash. A Hash of the metadata values.
  # * +options+                   - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:timeout+                  - Integer. A timeout in seconds.
  # * +:request_id+               - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                 in the analytics logs when storage analytics logging is enabled.
  #
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/set-directory-metadata
  #
  # Returns nil on success
  def set_directory_metadata(share, directory_path, metadata, options = {})
    # Query
    query = { "comp" => "metadata" }
    query["timeout"] = options[:timeout].to_s if options[:timeout]

    # Headers
    headers = {}
    StorageService.add_metadata_to_headers(metadata, headers) if metadata

    # Call
    call(:put, directory_uri(share, directory_path, query), nil, headers, options)

    # Result
    nil
  end

  # Public: Renames a source directory to a destination directory within the storage account.
  #
  # ==== Attributes
  #
  # * +destination_share+             - String. The name of the destination file share.
  # * +destination_directory_path+    - String. The path to the destination directory.
  # * +source_uri+                    - String. The source directory or directory URI to rename from.
  # * +options+                       - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:metadata+                   - Hash. Custom metadata values to store with the renamed directory. If this parameter is not
  #                                   specified, the operation will copy the source directory metadata to the destination
  #                                   directory. If this parameter is specified, the destination directory is created with the
  #                                   specified metadata, and metadata is not copied from the source directory.
  # * +:timeout+                    - Integer. A timeout in seconds.
  # * +:request_id+                 - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                   in the analytics logs when storage analytics logging is enabled.
  #
  def rename_directory_from_uri(destination_share, destination_directory_path, source_uri, options = {})
    query = { "comp" => "rename" }
    StorageService.with_query query, "timeout", options[:timeout].to_s if options[:timeout]

    uri = directory_uri(destination_share, destination_directory_path, query)
    headers = {}
    StorageService.with_header headers, "x-ms-file-rename-source", source_uri
    StorageService.with_header headers, "x-ms-source-lease-id", options[:source_lease_id] if options[:source_lease_id]
    StorageService.with_header headers, "x-ms-destination-lease-id", options[:destination_lease_id] if options[:destination_lease_id]
    StorageService.with_header headers, "x-ms-file-rename-replace-if-exists", "true" if options[:replace_if_exists]
    StorageService.add_metadata_to_headers options[:metadata], headers unless options.empty?
    # Having any value in "Content-Type" will cause this particular operation to fail.
    #   Note: the Content-Type header cannot be deleted because Net::HTTP will always set it; use an empty string instead
    StorageService.with_header headers, "Content-Type", ""

    response = call(:put, uri, nil, headers, options)

    # result
    nil
  end

  # Public: Renames a source directory to a destination directory within the same storage account.
  #
  # ==== Attributes
  #
  # * +destination_share+             - String. The destination share name to rename to.
  # * +destination_directory_path+    - String. The path to the destination directory to rename to.
  # * +source_share+                  - String. The source share name to rename from.
  # * +source_directory_path+         - String. The path to the source directory to rename from.
  # * +options+                       - Hash. Optional parameters.
  #
  # ==== Options
  #
  # Accepted key/value pairs in options parameter are:
  # * +:metadata+                   - Hash. Custom metadata values to store with the reanmed directory. If this parameter is not
  #                                   specified, the operation will copy the source directory metadata to the destination
  #                                   directory. If this parameter is specified, the destination directory is created with the
  #                                   specified metadata, and metadata is not copied from the source directory.
  # * +:timeout+                    - Integer. A timeout in seconds.
  # * +:request_id+                 - String. Provides a client-generated, opaque value with a 1 KB character limit that is recorded
  #                                   in the analytics logs when storage analytics logging is enabled.
  #
  def rename_directory(destination_share, destination_directory_path, source_share, source_directory_path, options = {})
    source_directory_uri = directory_uri(source_share, source_directory_path, {}).to_s

    # Header-based authorization where destination matches the source is hnadled automatically, but uri based authorization is not,
    #   so we need to sign the request manually if the source and destination shares are the same
    if source_share == destination_share
      source_dummy_request = Azure::Core::Http::HttpRequest.new(:get, source_directory_uri, body: "", headers: nil, client: @client)
      source_directory_uri = signer&.sign_request(source_dummy_request)&.uri || source_directory_uri
    end

    return rename_directory_from_uri(destination_share, destination_directory_path, source_directory_uri, options)
  end
end
