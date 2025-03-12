module CamaleonCms
  class Meta < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}metas"
    # attr_accessible :objectid, :key, :value, :object_class

    extend CamaleonCms::NormalizeAttrs

    normalize_attrs(:value)
  end
end
