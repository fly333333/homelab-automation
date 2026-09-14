# Ansible Methods

- **Command and Shell**
	Both the builtin `command` and `shell` will run unix/linux commands on the hosts, with `command` running the binaries directly on the hosts, while `shell` runs the command directly on the hosts in a shell environment. This means that you are able to use shell operators like `>`, `<`, `|`, `&`, and more. Additionally, due to these differences, `command` does not register or factor in shell variables. In general, `command` in a bit more secure and faster, while `shell` is more flexible.
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/shell_module.html
	*Example*: `ansible.builtin.command: timedatectl status`

- **Apt**
	For using the `apt` command that are typically used in unix/linux servers to download packages, or upgrade existing ones. The default choice for quickly downloading needed software.
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/apt_module.html
	*Example*: 
```yml
ansible.builtin.apt:
	update_cache: true
	upgrade: full
```

- **Template**
	Arguable the most useful feature using Ansible. Templating allows you to inject files into specific locations on hosts. These templates, typically using the `.j2` format, can host variables and logic within them. This allows for flexibility and customization per host. For the SIEM, templates are critical for setting configuration files in a way that is consistent and repeatable. 
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/template_module.html
	Example:
```yml
ansible.builtin.template:
	src: elasticsearch.conf.j2
    dest: /etc/security/limits.d/elasticsearch.conf
```

- **File**
	Create or modify files and directories. For example, you can `touch` a file with specific permissions, change a file to be executable, or a directory to be accessible to a user. 
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html#ansible-collections-ansible-builtin-file-module
	*Example*:
```yml
- name: Touch a file, using symbolic modes to set the permissions (equivalent to 0644)
  ansible.builtin.file:
    path: /etc/foo.conf
    state: touch
    mode: u=rw,g=r,o=r
```

- **Systemd_service**
	Software is often ran persistently (start at reboot, etc.) through the System Daemon, which read from `.service` files. Often you need to `start`, `enable`, or `restart` services. Fortunately, Ansible has this builtin module to manipulate this fairly easy. In this module, you specify the state that you *want* the state of the service to be. 
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/systemd_service_module.html
	*Example*:
```yml
- name: Make sure a service unit is running
  ansible.builtin.systemd_service:
    state: started
    name: httpd
```

- **Uri**
	Method for interacting with HTTP/HTTPS by creating a request to the site (i.e. `GET`, `POST`, etc.). The method allows you to specify authentication methods and whatever is needed in the body. This module is particularly useful for crafting API requests.
	*Docs*:
	- https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html
	*Example*:
```yml
- name: Create Agent Policy for Fleet Server
  ansible.builtin.uri:
	url: "http://{{ elastic_host }}:5601/api/fleet/agent_policies"
	method: POST
	user: elastic
	password: "{{ vault_elastic_password }}"
	validate_certs: false
	force_basic_auth: true
	headers:
	  kbn-xsrf: "true"
	  x-elastic-internal-origin: "Kibana"
	body_format: json
	body:
	  name: "Fleet Server Policy"
	  namespace: "default"
	  has_fleet_server: true
	status_code: 200
  register: fleet_server_policy
  until: fleet_server_policy.status == 200
  retries: 20
  delay: 5

```

