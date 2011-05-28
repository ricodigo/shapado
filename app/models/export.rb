class Export
  def initialize(group)
    @group = group
  end

  def export_model(model, io, opts = {})
    $stderr.puts ">> Exporting model #{model}"

    if model.kind_of?(MongoMapper::Document)
      io.write(model.to_json(opts)+"\n")
    elsif model.respond_to?(:klass)
      model.all.each do |object|
        io.write object.to_json({:except => [:_keywords]}.merge(opts)) + "\n"
      end
    else
      selector = opts.delete(:selector) || {:group_id => @group.id}

      puts "selector=#{selector.inspect}"
      model.where(selector).all.each do |object|
        io.write object.to_json({:except => [:_keywords]}.merge(opts)) + "\n"
      end
    end
  end

  def to_file(model, opts = {})
    File.open("#{collection_name_for(model)}.json", "w") do |file|
      export_model(model, file, opts)
    end
  end

  def to_zip(model, zf, opts = {})
    zf.file.open("#{collection_name_for(model)}.json", "w") do |file|
      export_model(model, file, opts)
    end
  end

  private
  def collection_name_for(model)
    if model.kind_of?(MongoMapper::Document)
      model.class.to_s.tableize
    elsif model.respond_to?(:klass)
      model.klass.to_s.tableize
    else
      model.to_s.tableize
    end
  end
end
