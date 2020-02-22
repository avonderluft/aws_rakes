class S3Bucket
  attr_reader :id, :name, :region, :encryption, :logging, :rules, :created
  def initialize(bucket, region, s3_client)
    @id = bucket.object_id
    @name = bucket.name
    @region = region
    @encryption = bucket_encryption(s3_client)
    @logging = bucket_logging(s3_client)
    @rules = lifecycle_rules(s3_client)
    @created = bucket.creation_date
  end

  def created_date
    created.to_s.split.first
  end

  def bucket_encryption(s3_client)
    @bucket_encryption ||= begin
      rules = s3_client.get_bucket_encryption(bucket: name).server_side_encryption_configuration.rules
      encrypt_hash = {}
      encrypt_hash['algorithm'] = rules.first.apply_server_side_encryption_by_default.sse_algorithm
      encrypt_hash['key'] = rules.first.apply_server_side_encryption_by_default.kms_master_key_id
      encrypt_hash
    rescue Aws::S3::Errors::ServerSideEncryptionConfigurationNotFoundError => nferr
      return {}
    rescue StandardError => e
      puts e.message.red
      return {}
    end
  end

  def bucket_logging(s3_client)
    logging_response = s3_client.get_bucket_logging(bucket: name).logging_enabled
    if logging_response
      logging_response.target_bucket
    else
      'none'
    end
  end

  def lifecycle_rules(s3_client)
    rules_array = []
    @lifecycle_rules ||= begin
      bucket_rules = s3_client.get_bucket_lifecycle(bucket: name).rules
      bucket_rules.each do |br|
        rules_array << "#{br.id}(#{br.status})"
      end
    rescue Aws::S3::Errors::NoSuchLifecycleConfiguration => nferr
      return []
    rescue StandardError => e
      puts e.message.red
      return []
    end
    rules_array
  end

  def encryption_output
    if encryption.empty?
      nil
    else
      "#{encryption['algorithm']}: #{encryption['key']}"
    end
  end

  def rules_output
    rules_string = ''
    rules.each { |rule| rules_string << "#{rule}, " }
    rules_string.strip.chomp(',')
  end

  def status_color
    if encryption.empty?
      'light_red'
    elsif logging == 'none'
      'light_yellow'
    else
      'light_green'
    end
  end

  def output_info
    output = { Name: name, Region: region, Encryption: encryption_output,
               Logging: logging, Rules: rules_output, Created: created_date }
    ap output, indent: 1, no_index: true, color: {string: status_color}
  end

end
