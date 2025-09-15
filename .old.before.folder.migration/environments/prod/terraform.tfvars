# ============================================================================
# PRODUCTION ENVIRONMENT - Full high availability and features
# ============================================================================

# # production.tfvars
# # RDS Configuration - Production Environment (Full Features)
# rds_postgres_version    = "16.9"
# rds_instance_class      = "db.t3.medium"       # Production sizing (~$60/month)
# rds_database_name       = "myapp_db"           # Match your application
# rds_database_username   = "myapp"              # Match your application
# rds_database_port       = 5432

# # This table name gets created on app initialization (backend)
# rds_postgres_table_name = "messages"

# # Storage (Production capacity and performance)
# rds_allocated_storage     = 100     # Adequate starting storage
# rds_max_allocated_storage = 500     # Allow significant growth
# rds_storage_type          = "gp3"   # High performance storage
# rds_storage_encrypted         = true    # Always encrypt in production

# # Multi-AZ and High Availability (CRITICAL for production)
# rds_multi_az_enabled = true             # Enable Multi-AZ for high availability

# # Backup and maintenance (Production-grade retention)
# rds_backup_retention_period = 30                    # 30 days retention
# rds_backup_window          = "03:00-04:00"          # Low traffic time UTC
# rds_maintenance_window     = "sun:04:00-sun:06:00"  # Sunday early morning

# # Protection and snapshot settings (Maximum protection)
# rds_deletion_protection = true      # Protect production database
# rds_skip_final_snapshot = false     # Always take final snapshot

# # Monitoring (Full monitoring and insights)
# rds_enable_performance_insights = true   # Enable Performance Insights
# rds_monitoring_interval         = 60     # 1-minute detailed monitoring

# # Additional settings
# rds_copy_tags_to_snapshot = true             # Always copy tags in production
