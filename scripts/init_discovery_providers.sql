-- 初始化15个内置Discovery Provider的Schema数据

INSERT INTO `io_discovery_provider_schemas` 
(`provider_id`, `provider_name`, `category`, `description`, `version`, `icon_url`, 
 `parameter_schema`, `field_schema`, `is_active`, `is_builtin`, `execution_mode`, `created_at`, `updated_at`)
VALUES

-- 1. nb_agent - NewBee Agent自动发现(核心)
('nb_agent', 'NewBee Agent', 'agent', '通过NewBee Agent自动发现和采集服务器信息', '1.0.0', '/icons/nb-agent.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'agent_endpoint', 'label', 'Agent地址', 'type', 'string', 'required', true, 'placeholder', 'http://192.168.1.100:8888'),
   JSON_OBJECT('name', 'auth_token', 'label', '认证Token', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'timeout_seconds', 'label', '超时时间(秒)', 'type', 'int', 'defaultValue', 30)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'hostname', 'label', '主机名', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ip_address', 'label', 'IP地址', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'os_type', 'label', '操作系统类型', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'os_version', 'label', '操作系统版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'kernel_version', 'label', '内核版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'cpu_model', 'label', 'CPU型号', 'dataType', 'string'),
   JSON_OBJECT('name', 'cpu_cores', 'label', 'CPU核心数', 'dataType', 'integer'),
   JSON_OBJECT('name', 'memory_total_gb', 'label', '内存总量(GB)', 'dataType', 'float'),
   JSON_OBJECT('name', 'disk_total_gb', 'label', '磁盘总量(GB)', 'dataType', 'float'),
   JSON_OBJECT('name', 'agent_version', 'label', 'Agent版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'uptime_seconds', 'label', '运行时间(秒)', 'dataType', 'integer')
 ),
 true, true, 'direct', NOW(), NOW()),

-- 2. vmware_vcenter - VMware vCenter
('vmware_vcenter', 'VMware vCenter', 'api', '通过vCenter API发现虚拟机资源', '1.0.0', '/icons/vmware.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', 'vCenter地址', 'type', 'string', 'required', true, 'placeholder', 'vcenter.example.com'),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'port', 'label', '端口', 'type', 'int', 'defaultValue', 443),
   JSON_OBJECT('name', 'verify_ssl', 'label', '验证SSL证书', 'type', 'boolean', 'defaultValue', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'name', 'label', '虚拟机名称', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ipAddress', 'label', 'IP地址', 'dataType', 'string'),
   JSON_OBJECT('name', 'numCPU', 'label', 'CPU数量', 'dataType', 'integer'),
   JSON_OBJECT('name', 'memorySizeMB', 'label', '内存大小(MB)', 'dataType', 'integer'),
   JSON_OBJECT('name', 'diskSizeGB', 'label', '磁盘大小(GB)', 'dataType', 'float'),
   JSON_OBJECT('name', 'powerState', 'label', '电源状态', 'dataType', 'string'),
   JSON_OBJECT('name', 'guestOS', 'label', '客户机操作系统', 'dataType', 'string'),
   JSON_OBJECT('name', 'cluster', 'label', '集群名称', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 3. vmware_esxi - VMware ESXi
('vmware_esxi', 'VMware ESXi', 'api', 'VMware ESXi单机虚拟化发现', '1.0.0', '/icons/vmware.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', 'ESXi地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password', 'required', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'name', 'label', '虚拟机名称', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ipAddress', 'label', 'IP地址', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 4. linux_ssh - Linux SSH发现
('linux_ssh', 'Linux SSH', 'api', 'Linux服务器SSH远程发现', '1.0.0', '/icons/linux.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', '服务器地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'port', 'label', 'SSH端口', 'type', 'int', 'defaultValue', 22),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'auth_method', 'label', '认证方式', 'type', 'select', 'options', JSON_ARRAY('password', 'ssh_key'), 'defaultValue', 'password'),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password'),
   JSON_OBJECT('name', 'private_key', 'label', 'SSH私钥', 'type', 'textarea')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'hostname', 'label', '主机名', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ip_address', 'label', 'IP地址', 'dataType', 'string'),
   JSON_OBJECT('name', 'os_version', 'label', '操作系统版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'kernel_version', 'label', '内核版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'cpu_cores', 'label', 'CPU核心数', 'dataType', 'integer'),
   JSON_OBJECT('name', 'memory_total_gb', 'label', '内存总量(GB)', 'dataType', 'float')
 ),
 true, true, 'agent', NOW(), NOW()),

-- 5. windows_wmi - Windows WMI发现
('windows_wmi', 'Windows WMI', 'api', 'Windows服务器WMI远程发现', '1.0.0', '/icons/windows.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', '服务器地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'domain', 'label', '域名', 'type', 'string')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'hostname', 'label', '主机名', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ip_address', 'label', 'IP地址', 'dataType', 'string'),
   JSON_OBJECT('name', 'os_version', 'label', '操作系统版本', 'dataType', 'string'),
   JSON_OBJECT('name', 'cpu_cores', 'label', 'CPU核心数', 'dataType', 'integer'),
   JSON_OBJECT('name', 'memory_total_gb', 'label', '内存总量(GB)', 'dataType', 'float')
 ),
 true, true, 'agent', NOW(), NOW()),

-- 6. aliyun_ecs - 阿里云ECS
('aliyun_ecs', '阿里云ECS', 'sdk', '阿里云ECS实例自动发现', '1.0.0', '/icons/aliyun.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'access_key_id', 'label', 'AccessKey ID', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'access_key_secret', 'label', 'AccessKey Secret', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'region_id', 'label', '地域ID', 'type', 'select', 'options', JSON_ARRAY('cn-beijing', 'cn-shanghai', 'cn-hangzhou', 'cn-shenzhen'), 'defaultValue', 'cn-beijing')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'instance_id', 'label', '实例ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'instance_name', 'label', '实例名称', 'dataType', 'string'),
   JSON_OBJECT('name', 'public_ip', 'label', '公网IP', 'dataType', 'string'),
   JSON_OBJECT('name', 'private_ip', 'label', '私网IP', 'dataType', 'string'),
   JSON_OBJECT('name', 'instance_type', 'label', '实例规格', 'dataType', 'string'),
   JSON_OBJECT('name', 'cpu', 'label', 'CPU核数', 'dataType', 'integer'),
   JSON_OBJECT('name', 'memory', 'label', '内存(GB)', 'dataType', 'integer'),
   JSON_OBJECT('name', 'os_type', 'label', '操作系统类型', 'dataType', 'string'),
   JSON_OBJECT('name', 'status', 'label', '实例状态', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 7. tencent_cvm - 腾讯云CVM
('tencent_cvm', '腾讯云CVM', 'sdk', '腾讯云CVM实例自动发现', '1.0.0', '/icons/tencent.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'secret_id', 'label', 'SecretId', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'secret_key', 'label', 'SecretKey', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'region', 'label', '地域', 'type', 'select', 'options', JSON_ARRAY('ap-beijing', 'ap-shanghai', 'ap-guangzhou'), 'defaultValue', 'ap-beijing')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'instance_id', 'label', '实例ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'instance_name', 'label', '实例名称', 'dataType', 'string'),
   JSON_OBJECT('name', 'public_ip', 'label', '公网IP', 'dataType', 'string'),
   JSON_OBJECT('name', 'private_ip', 'label', '私网IP', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 8. aws_ec2 - AWS EC2
('aws_ec2', 'AWS EC2', 'sdk', 'AWS EC2实例自动发现', '1.0.0', '/icons/aws.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'access_key_id', 'label', 'Access Key ID', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'secret_access_key', 'label', 'Secret Access Key', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'region', 'label', 'Region', 'type', 'string', 'required', true, 'placeholder', 'us-east-1')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'instance_id', 'label', '实例ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'instance_type', 'label', '实例类型', 'dataType', 'string'),
   JSON_OBJECT('name', 'public_ip', 'label', '公网IP', 'dataType', 'string'),
   JSON_OBJECT('name', 'private_ip', 'label', '私网IP', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 9. huawei_ecs - 华为云ECS
('huawei_ecs', '华为云ECS', 'sdk', '华为云ECS实例自动发现', '1.0.0', '/icons/huawei.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'access_key', 'label', 'Access Key', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'secret_key', 'label', 'Secret Key', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'region', 'label', '区域', 'type', 'string', 'required', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'instance_id', 'label', '实例ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'instance_name', 'label', '实例名称', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 10. azure_vm - Azure虚拟机
('azure_vm', 'Azure虚拟机', 'sdk', 'Azure虚拟机自动发现', '1.0.0', '/icons/azure.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'tenant_id', 'label', 'Tenant ID', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'client_id', 'label', 'Client ID', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'client_secret', 'label', 'Client Secret', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'subscription_id', 'label', 'Subscription ID', 'type', 'string', 'required', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'vm_id', 'label', '虚拟机ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'vm_name', 'label', '虚拟机名称', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 11. openstack - OpenStack
('openstack', 'OpenStack', 'api', 'OpenStack云平台资源发现', '1.0.0', '/icons/openstack.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'auth_url', 'label', '认证地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password', 'required', true),
   JSON_OBJECT('name', 'project_name', 'label', '项目名称', 'type', 'string', 'required', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'instance_id', 'label', '实例ID', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'instance_name', 'label', '实例名称', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 12. snmp_device - SNMP网络设备
('snmp_device', 'SNMP网络设备', 'api', 'SNMP协议网络设备发现', '1.0.0', '/icons/network.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', '设备地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'community', 'label', 'Community', 'type', 'string', 'required', true, 'defaultValue', 'public'),
   JSON_OBJECT('name', 'version', 'label', 'SNMP版本', 'type', 'select', 'options', JSON_ARRAY('v1', 'v2c', 'v3'), 'defaultValue', 'v2c')
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'hostname', 'label', '设备名称', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ip_address', 'label', 'IP地址', 'dataType', 'string'),
   JSON_OBJECT('name', 'device_type', 'label', '设备类型', 'dataType', 'string'),
   JSON_OBJECT('name', 'vendor', 'label', '厂商', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 13. ssh_network - SSH网络设备
('ssh_network', 'SSH网络设备', 'api', 'SSH协议网络设备发现', '1.0.0', '/icons/network.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'host', 'label', '设备地址', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'port', 'label', 'SSH端口', 'type', 'int', 'defaultValue', 22),
   JSON_OBJECT('name', 'username', 'label', '用户名', 'type', 'string', 'required', true),
   JSON_OBJECT('name', 'password', 'label', '密码', 'type', 'password', 'required', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'hostname', 'label', '设备名称', 'dataType', 'string', 'required', true),
   JSON_OBJECT('name', 'ip_address', 'label', 'IP地址', 'dataType', 'string'),
   JSON_OBJECT('name', 'device_type', 'label', '设备类型', 'dataType', 'string')
 ),
 true, true, 'worker', NOW(), NOW()),

-- 14. file_import - 文件导入
('file_import', '文件导入', 'file', 'CSV/Excel/JSON文件批量导入', '1.0.0', '/icons/file.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'file_type', 'label', '文件类型', 'type', 'select', 'options', JSON_ARRAY('csv', 'excel', 'json'), 'required', true),
   JSON_OBJECT('name', 'file_content', 'label', '文件内容', 'type', 'file', 'required', true),
   JSON_OBJECT('name', 'encoding', 'label', '文件编码', 'type', 'select', 'options', JSON_ARRAY('utf-8', 'gbk', 'gb2312'), 'defaultValue', 'utf-8'),
   JSON_OBJECT('name', 'has_header', 'label', '包含表头', 'type', 'boolean', 'defaultValue', true)
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'dynamic', 'label', '动态字段', 'dataType', 'dynamic', 'description', '根据文件内容动态生成')
 ),
 true, true, 'direct', NOW(), NOW()),

-- 15. api_custom - 自定义API接口
('api_custom', '自定义API', 'api', '自定义HTTP API接口发现', '1.0.0', '/icons/api.svg',
 JSON_ARRAY(
   JSON_OBJECT('name', 'url', 'label', 'API地址', 'type', 'string', 'required', true, 'placeholder', 'https://api.example.com/devices'),
   JSON_OBJECT('name', 'method', 'label', '请求方法', 'type', 'select', 'options', JSON_ARRAY('GET', 'POST'), 'defaultValue', 'GET'),
   JSON_OBJECT('name', 'headers', 'label', '请求头', 'type', 'textarea', 'placeholder', 'JSON格式'),
   JSON_OBJECT('name', 'body', 'label', '请求体', 'type', 'textarea', 'placeholder', 'JSON格式'),
   JSON_OBJECT('name', 'auth_type', 'label', '认证类型', 'type', 'select', 'options', JSON_ARRAY('none', 'basic', 'bearer', 'api_key'))
 ),
 JSON_ARRAY(
   JSON_OBJECT('name', 'dynamic', 'label', '动态字段', 'dataType', 'dynamic', 'description', '根据API响应动态生成')
 ),
 true, true, 'worker', NOW(), NOW());
