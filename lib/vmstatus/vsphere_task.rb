require 'rbvmomi'
require 'vmstatus/vm'
require 'resolv'

class Vmstatus::VsphereTask
  def initialize(opts)
    @host = opts[:host]
    @user = opts[:user]
    @password = opts[:password]
    @datacenter = opts[:datacenter]
    @cluster = opts[:cluster]
    @vmpoolers = opts[:vmpoolers]
  end

  def run(&block)
    puts "Querying vsphere '#{@host}' for VMs in cluster '#{@cluster}' in datacenter '#{@datacenter}' for vmpoolers " + @vmpoolers.join(", ")

    with_connection do |conn|
      dc = conn.serviceInstance.find_datacenter(@datacenter)

      raise ArgumentError.new("Datacenter not found: #{@datacenter}") if dc.nil?

      clusterComputeResource = dc.find_compute_resource(@cluster)

      raise ArgumentError.new("Cluster not found: #{@cluster}") if clusterComputeResource.nil?

      begin
        template_uuids = list_template_uuids(conn, dc, %w(templates packer))

        list_vms(conn, clusterComputeResource.resourcePool, template_uuids, &block)
      rescue => e
        $stderr.puts "vsphere failed: #{e.message}"
      end
    end
  end

  def list_vms(conn, resourcePool, template_uuids, &block)
    # List all VirtualMachine names and powerstate that are reachable by
    # traversing (recursively) all ResourcePools associated with the cluster
    #
    # Cluster -->* ResourcePool -->* VirtualMachine
    #                |   /\*
    #                |   |
    #                +---+
    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
      objectSet: [
        {
          obj: resourcePool,
          selectSet: [
            RbVmomi::VIM.TraversalSpec(
            name: 'tsFolder',
            type: 'ResourcePool',
            path: 'resourcePool',
            skip: false,
            selectSet: [
              RbVmomi::VIM.SelectionSpec(name: 'tsFolder'),
              RbVmomi::VIM.SelectionSpec(name: 'tsVM'),
            ]
          ),
            RbVmomi::VIM.TraversalSpec(
              name: 'tsVM',
              type: 'ResourcePool',
              path: 'vm',
              skip: false,
              selectSet: [],
            )
          ]
        }
      ],
      propSet: [
        { type: 'VirtualMachine', pathSet: %w(name config.instanceUuid runtime.powerState runtime.host guest.ipAddress config.annotation) }
      ]
    )

    result = conn.propertyCollector.RetrieveProperties(:specSet => [filterSpec])
    result.map do |obj|
      if !template_uuids.include?(obj['config.instanceUuid'])
        if obj['runtime.host'].nil? || obj['runtime.host'].name.nil?
          cluster_host = "N/A"
        else
          cluster_host = obj['runtime.host'].name
        end

        on = obj['runtime.powerState']
        if on.nil?
          on = "N/A"
        elsif on == "poweredOff"
          on = "off"
        elsif on == "poweredOn"
          on = "on"
        else
          on = "wha"
        end

        if obj['guest.ipAddress'].nil?
          vmip = "N/A"
        else
          vmip = obj['guest.ipAddress']
        end

        domain_name = "delivery.puppetlabs.net"
        if obj['name'].include?(domain_name)
          fqdn = obj['name']
        else
          fqdn = "#{obj['name']}.#{domain_name}"
        end

        if on.nil?
          dnsip = "N/A"
        else
          begin
            dnsip = Resolv.getaddress(fqdn)
          rescue
            puts "Error trying to DNS resolve fqdn #{fqdn}"
            dnsip = "N/A"
          end
        end

        #process annotation
        # {name, created_by, base_template, creation_timestamp}
        if obj['config.annotation'].nil? || !valid_json?(obj['config.annotation'])
          annotation = "N/A"
        else
          annotation = JSON.parse(obj['config.annotation'])
        end


        vsphere_status = {
          :uuid => obj['config.instanceUuid'],
          :on => on,
          :clusterhost => cluster_host,
          :vmip => vmip,
          :dnsip => dnsip,
          :created_by => annotation['created_by'],
          :creation_timestamp => annotation['creation_timestamp']
        }

        # template names aren't unique, but vm names generally are
        yield obj['name'], vsphere_status
      end
    end
  end

  def valid_json?(json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError => e
    return false
  end


  def list_template_uuids(conn, dc, folders)
    template_uuids = Set.new

    folders.each do |name|
      folder = dc.find_folder(name)

      raise ArgumentError.new("Templates folder not found") if folder.nil?

      filterSpec = RbVmomi::VIM.PropertyFilterSpec(
        objectSet: [
          {
            obj: folder,
            selectSet: [
              RbVmomi::VIM.TraversalSpec(
              name: 'tsFolder',
              type: 'Folder',
              path: 'childEntity',
              skip: false,
              selectSet: [
                RbVmomi::VIM.SelectionSpec(name: 'tsFolder'),
              ]
            )]
          }
        ],
        propSet: [
          { type: 'VirtualMachine', pathSet: %w(name config.instanceUuid runtime.powerState) }
        ]
      )

      result = conn.propertyCollector.RetrieveProperties(:specSet => [filterSpec])
      result.each do |obj|
        template_uuids.add(obj['config.instanceUuid'])
      end
    end

    template_uuids
  end

  def with_connection
    conn = RbVmomi::VIM.connect(host: @host,
                                user: @user,
                                password: @password,
                                ssl: true,
                                insecure: true)
    begin
      yield conn
    ensure
      conn.close
    end
  end
end
