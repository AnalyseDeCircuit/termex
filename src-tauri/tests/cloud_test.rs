use termex_lib::cloud::kube;
use termex_lib::cloud::ssm;

fn fixture(name: &str) -> String {
    let path = format!(
        "{}/tests/fixtures/{}",
        env!("CARGO_MANIFEST_DIR"),
        name
    );
    std::fs::read_to_string(path).expect("fixture file not found")
}

// ── K8s context parsing ─────────────────────────────────────

#[test]
fn test_kube_context_parse_basic() {
    let json = fixture("kube_config_view.json");
    let contexts = kube::parse_contexts(&json).unwrap();

    assert_eq!(contexts.len(), 3);
    assert_eq!(contexts[0].name, "production");
    assert_eq!(contexts[0].cluster, "prod-cluster");
    assert_eq!(contexts[0].user, "admin");
    assert_eq!(contexts[0].namespace, Some("default".to_string()));
    assert!(contexts[0].is_current);
}

#[test]
fn test_kube_context_parse_non_current() {
    let json = fixture("kube_config_view.json");
    let contexts = kube::parse_contexts(&json).unwrap();

    let staging = &contexts[1];
    assert_eq!(staging.name, "staging");
    assert_eq!(staging.cluster, "stg-cluster");
    assert_eq!(staging.user, "dev-user");
    assert_eq!(staging.namespace, None);
    assert!(!staging.is_current);
}

#[test]
fn test_kube_context_parse_all_contexts() {
    let json = fixture("kube_config_view.json");
    let contexts = kube::parse_contexts(&json).unwrap();

    let names: Vec<&str> = contexts.iter().map(|c| c.name.as_str()).collect();
    assert_eq!(names, vec!["production", "staging", "minikube"]);

    let current_count = contexts.iter().filter(|c| c.is_current).count();
    assert_eq!(current_count, 1);
}

#[test]
fn test_kube_context_parse_invalid_json() {
    let result = kube::parse_contexts("not json");
    assert!(result.is_err());
}

// ── K8s pod parsing ─────────────────────────────────────────

#[test]
fn test_kube_pod_json_parse_basic() {
    let json = fixture("kube_pods.json");
    let pods = kube::parse_pod_list(&json).unwrap();

    assert_eq!(pods.len(), 3);
}

#[test]
fn test_kube_pod_single_container() {
    let json = fixture("kube_pods.json");
    let pods = kube::parse_pod_list(&json).unwrap();

    let nginx = &pods[0];
    assert_eq!(nginx.name, "nginx-deploy-abc123");
    assert_eq!(nginx.namespace, "default");
    assert_eq!(nginx.status, "Running");
    assert_eq!(nginx.ready, "1/1");
    assert_eq!(nginx.restarts, 0);
    assert_eq!(nginx.node, "node-1");
    assert_eq!(nginx.containers.len(), 1);
    assert_eq!(nginx.containers[0].name, "nginx");
    assert!(nginx.containers[0].ready);
    assert_eq!(nginx.containers[0].state, "running");
}

#[test]
fn test_kube_pod_multi_container() {
    let json = fixture("kube_pods.json");
    let pods = kube::parse_pod_list(&json).unwrap();

    let api = &pods[1];
    assert_eq!(api.name, "api-server-xyz789");
    assert_eq!(api.containers.len(), 2);
    assert_eq!(api.ready, "2/2");
    assert_eq!(api.restarts, 3); // sum of all container restarts
    assert_eq!(api.containers[0].name, "api");
    assert_eq!(api.containers[0].restart_count, 3);
    assert_eq!(api.containers[1].name, "sidecar");
    assert_eq!(api.containers[1].restart_count, 0);
}

#[test]
fn test_kube_pod_failed_status() {
    let json = fixture("kube_pods.json");
    let pods = kube::parse_pod_list(&json).unwrap();

    let worker = &pods[2];
    assert_eq!(worker.name, "worker-failed-001");
    assert_eq!(worker.status, "Failed");
    assert_eq!(worker.ready, "0/1");
    assert_eq!(worker.restarts, 5);
    assert!(!worker.containers[0].ready);
    assert_eq!(worker.containers[0].state, "terminated");
}

#[test]
fn test_kube_pod_age_is_nonempty() {
    let json = fixture("kube_pods.json");
    let pods = kube::parse_pod_list(&json).unwrap();

    for pod in &pods {
        assert!(!pod.age.is_empty(), "Pod {} should have age computed", pod.name);
    }
}

#[test]
fn test_kube_pod_parse_invalid_json() {
    let result = kube::parse_pod_list("{}");
    assert!(result.is_err());
}

// ── SSM instance parsing ────────────────────────────────────

#[test]
fn test_ssm_instance_parse_basic() {
    let json = fixture("ssm_instances.json");
    let instances = ssm::parse_instances(&json).unwrap();

    assert_eq!(instances.len(), 3);
}

#[test]
fn test_ssm_instance_online() {
    let json = fixture("ssm_instances.json");
    let instances = ssm::parse_instances(&json).unwrap();

    let web = &instances[0];
    assert_eq!(web.instance_id, "i-0abc1234def56789");
    assert_eq!(web.name, "web-server-1");
    assert_eq!(web.platform, "Linux");
    assert_eq!(web.ip_address, Some("10.0.1.100".to_string()));
    assert_eq!(web.ping_status, "Online");
}

#[test]
fn test_ssm_instance_offline() {
    let json = fixture("ssm_instances.json");
    let instances = ssm::parse_instances(&json).unwrap();

    let batch = &instances[2];
    assert_eq!(batch.instance_id, "i-0ghi0000aaabbbcc");
    assert_eq!(batch.name, "batch-worker");
    assert_eq!(batch.platform, "Windows");
    assert_eq!(batch.ip_address, None);
    assert_eq!(batch.ping_status, "ConnectionLost");
}

#[test]
fn test_ssm_instance_parse_invalid_json() {
    let result = ssm::parse_instances("{}");
    assert!(result.is_err());
}

// ── Command args safety ─────────────────────────────────────

#[test]
fn test_command_args_no_injection() {
    use portable_pty::CommandBuilder;

    let malicious_pod = "\"; rm -rf /; echo \"";
    let mut cmd = CommandBuilder::new("kubectl");
    cmd.args(["exec", "-it", malicious_pod, "--", "/bin/sh"]);

    // CommandBuilder stores args as separate entries, not shell-expanded.
    // This test verifies the pattern works — the malicious string stays as one arg.
    let args = cmd.get_argv();
    assert!(args.iter().any(|a| a.to_string_lossy().contains("rm -rf")));
    // The key point: it's a single arg element, not split by shell.
    let pod_arg = args.iter().find(|a| a.to_string_lossy().contains("rm -rf")).unwrap();
    assert_eq!(pod_arg.to_string_lossy(), malicious_pod);
}
