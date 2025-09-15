# ============================================================================
# STAGING ENVIRONMENT - Cost-optimized with some production features
# ============================================================================

# # staging.tfvars
# # RDS Configuration - Staging Environment (Cost-Optimized)
# rds_postgres_version    = "16.9"
# rds_instance_class      = "db.t3.small"        # Step up from micro (~$25/month)
# rds_database_name       = "myapp_db"           # Match your application
# rds_database_username   = "myapp"              # Match your application
# rds_database_port       = 5432

# # This table name gets created on app initialization (backend)
# rds_postgres_table_name = "messages"

# # Storage (Improved performance and capacity)
# rds_allocated_storage     = 50      # More space for staging data
# rds_max_allocated_storage = 100     # Allow growth for testing
# rds_storage_type          = "gp3"   # Better performance than gp2
# rds_storage_encrypted         = true    # Enable encryption for staging

# # Multi-AZ and High Availability
# rds_multi_az_enabled = false            # Still single AZ to save costs (~$25/month savings)

# # Backup and maintenance (Better retention for staging)
# rds_backup_retention_period = 7                     # 7 days retention
# rds_backup_window          = "03:00-04:00"          # Low traffic time UTC
# rds_maintenance_window     = "sun:04:00-sun:06:00"  # Longer window for updates

# # Protection and snapshot settings (Staging safety)
# rds_deletion_protection = false     # Can still destroy staging easily
# rds_skip_final_snapshot = false     # Take snapshot for staging data recovery

# # Monitoring (Enhanced monitoring)
# rds_enable_performance_insights = true   # Enable PI for staging testing
# rds_monitoring_interval         = 60     # 1-minute monitoring

# # Additional settings
# rds_copy_tags_to_snapshot = true             # Copy tags to snapshots
