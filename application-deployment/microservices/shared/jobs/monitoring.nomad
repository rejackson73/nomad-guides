job "monitoring" {
  datacenters = ["dc1"]
  priority = 10
  #namespace= "monitor"

  type = "service"
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
  update {
    stagger = "10s"
    max_parallel = 1  
  }
  group "foundation" {
    count = 1 
    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }
    ephemeral_disk {
      size = 3000
    }
    task "fluentd" {
      driver = "docker"
      config {
        image = "fluent/fluentd"
        port_map {
          fluentd = 24224
        }
      }
      resources {
        cpu    = 2000 # 2000 MHz
        memory = 3072 # 3GB
        network {
          mbits = 10
          port "fluentd" {}
        }
      }
      service {
        name = "monitoring-fluentd"
        tags = [
        "monitoring",
                "traefik.tags=pink,lolcats",
                "traefik.frontend.rule=Host:fluentd.local"
    ]
        port = "fluentd"
      }
    }
  }
}