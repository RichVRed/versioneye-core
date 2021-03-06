require 'spec_helper'

describe CargoLockParser do
  let(:parser){ CargoLockParser.new }
  let(:test_filepath){ 'spec/fixtures/files/cargo/Cargo.lock' }
  let(:dep_line1){
    'httparse 1.2.1 (registry+https://github.com/rust-lang/crates.io-index)'
  }
  let(:dep_line2){
    'log 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)'
  }

  let(:product1){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'httparse',
      name: 'httparse',
      version: '1.2.1'
    )
  }

  let(:product2){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'log',
      name: 'log',
      version: '0.3.6'
    )
  }

  context "parse_dependency_line" do
    it "extracts correct fields from dep_line1" do
      pkg_id, version = parser.parse_dependency_line dep_line1
      expect(pkg_id.nil?).to be_falsey
      expect(pkg_id).to eq(product1[:name])
      expect(version).to eq(product1[:version])
    end

    it "extracts correct fields from dep_line2" do
      pkg_id, version = parser.parse_dependency_line dep_line2
      expect(pkg_id).not_to be_nil
      expect(pkg_id).to eq(product2[:name])
      expect(version).to eq(product2[:version])
    end
  end

  let(:dep1){
    Projectdependency.new(
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'libc',
      name: 'libc'
    )
  }

  context "parse_requested_version" do
    after do
      Project.delete_all
      Projectdependency.delete_all
    end

    it "updates dependency versions if product and it version exists" do
      product1.versions << Version.new(version: '0.3.6')
      product1.save

      dep = parser.parse_requested_version '0.3.6', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.3.6')
      expect(dep[:version_label]).to eq('0.3.6')
      expect(dep[:comperator]).to eq('=')
    end

    it "updates dependency with the latest product version when no such version" do
      product1.versions << Version.new(version: '0.3.6')
      product1.save

      dep = parser.parse_requested_version '0.2.1', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.3.6')
      expect(dep[:version_label]).to eq('0.2.1')
      expect(dep[:comperator]).to eq('=')
    end

    it "uses version label when product is nil" do
      dep = parser.parse_requested_version('0.10.1', dep1, nil)
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.10.1')
      expect(dep[:version_label]).to eq('0.10.1')
      expect(dep[:comperator]).to eq('=')
    end
  end


  let(:project_doc1){
    {
      :root => {
        name: 'test_single_parent',
        version: '0.0.1',
        dependencies: ['httparse 1.2.1 (registry+https://url.com)']
      },
      :package => [
        {
          name: 'httparse',
          version: '1.2.1',
          source: 'registry+https://url.com'
        }
      ]
    }
  }

  let(:project1){
    parser.init_project(project_doc1)
  }

  let(:project_doc2){
    {
      :root => {
        name: 'test_parent_with_child',
        version: '0.0.2',
        dependencies: ['httparse 1.2.1 (registry+https://url.com)']
      },
      :package => [
        {
          name: 'httparse',
          version: '1.2.1',
          source: 'registry+https://url.com',
          dependencies: [
            'log 0.3.6 (registry+https://url2.com)'
          ]
        },
        {
          name: 'log',
          version: '0.3.6',
          source: 'registry+https://url2.com'
        }
      ]
    }
  }

  context "parse_recursive_dependencies" do
    before do
      product1.versions << Version.new(version: '1.2.1')
      product1.save

      product2.versions << Version.new(version: '0.3.6')
      product2.save
    end

    it "parses correctly parent without children" do
      packages_idx = parser.build_package_index(project_doc1[:package])

      expect(project1.dependencies.size).to eq(0)

      dep_line = project_doc1[:root][:dependencies].first
      parser.parse_recursive_dependencies(
        project1, packages_idx, dep_line
      )

      expect(project1.dependencies.size).to eq(1)
      dep1 = project1.dependencies[0]
      expect(dep1[:prod_key]).to eq(product1[:prod_key])
      expect(dep1[:name]).to eq(product1[:name])
      expect(dep1[:version_requested]).to eq(product1[:version])
      expect(dep1[:version_label]).to eq(product1[:version])
      expect(dep1[:comperator]).to eq('=')
    end


    it "parses correctly parent with child" do
      project2 = parser.init_project( project_doc2 )
      packages_idx = parser.build_package_index(project_doc2[:package])

      expect(project2.dependencies.size).to eq(0)
      dep_line = project_doc2[:root][:dependencies].first
      parser.parse_recursive_dependencies(
        project2, packages_idx, dep_line
      )

      expect(project2.dependencies.size).to eq(2)

      dep1 = project2.dependencies[0]
      expect(dep1[:prod_key]).to eq(product1[:prod_key])
      expect(dep1[:name]).to eq(product1[:name])
      expect(dep1[:version_requested]).to eq(product1[:version])
      expect(dep1[:version_label]).to eq(product1[:version])
      expect(dep1[:comperator]).to eq('=')

      dep2 = project2.dependencies[1]
      expect(dep2[:prod_key]).to eq(product2[:prod_key])
      expect(dep2[:name]).to eq(product2[:name])
      expect(dep2[:version_requested]).to eq(product2[:version])
      expect(dep2[:version_label]).to eq(product2[:version])
      expect(dep2[:comperator]).to eq('=')
      expect(dep2[:transitive]).to be_truthy
      expect(dep2[:parent_id]).to eq(dep1.id)
      expect(dep2[:parent_prod_key]).to eq(product1[:prod_key])
      expect(dep2[:parent_version]).to eq(product1[:version])
    end
  end


  let(:product3){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'kernel32-sys',
      name: 'kernel32-sys',
      version: '0.1.0'
    )
  }

  let(:product4){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'winapi',
      name: 'winapi',
      version: '0.1.20'
    )
  }

  let(:product5){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'libc',
      name: 'libc',
      version: '0.1.8'
    )
  }

  let(:product6){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'user32-sys',
      name: 'user32-sys',
      version: '0.1.1'
    )
  }

  let(:product7){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'winapi-build',
      name: 'winapi-build',
      version: '0.1.0'
    )
  }

  let(:product8){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'winmm-sys',
      name: 'winmm-sys',
      version: '0.1.0'
    )
  }


  context "parse_content" do
    before do
      product3.versions << Version.new(version: '0.1.0')
      product3.versions << Version.new(version: '0.2.0')
      product3.save

      product4.versions << Version.new(version: '0.1.20')
      product4.save

      product5.versions << Version.new(version: '0.1.8')
      product5.save

      product6.versions << Version.new(version: '0.1.1')
      product6.save

      product7.versions << Version.new(version: '0.1.0')
      product7.save

      product8.versions << Version.new(version: '0.1.0')
      product8.save

    end

    after do
      Project.delete_all
      Projectdependency.delete_all
    end

    it "parses correctly test file" do
      content = File.read test_filepath
      proj = parser.parse_content content
      expect(proj).not_to be_nil
      expect(proj.dependencies.size).to eq(9)
      expect(proj.dep_number).to eq(9)


      dep1 = proj.dependencies[0]
      expect(dep1[:name]).to eq(product3[:name])
      expect(dep1[:prod_key]).to eq(product3[:prod_key])
      expect(dep1[:version_requested]).to eq(product3[:version])
      expect(dep1[:version_label]).to eq(product3[:version])
      expect(dep1[:comperator]).to eq('=')
      expect(dep1[:outdated]).to be_truthy
      expect(dep1[:transitive]).to be_falsey

      dep2 = proj.dependencies[1]
      expect(dep2[:name]).to eq(product4[:name])
      expect(dep2[:prod_key]).to eq(product4[:prod_key])
      expect(dep2[:version_requested]).to eq(product4[:version])
      expect(dep2[:version_label]).to eq(product4[:version])
      expect(dep2[:comperator]).to eq('=')
      expect(dep2[:outdated]).to be_falsey
      expect(dep2[:transitive]).to be_truthy
      expect(dep2[:deepness]).to eq(1)
      expect(dep2[:parent_id]).to eq(dep1.id)
      expect(dep2[:parent_prod_key]).to eq(dep1[:prod_key])
      expect(dep2[:parent_version]).to eq(dep1[:version_label])

      dep3 = proj.dependencies[2]
      expect(dep3[:name]).to eq(product5[:name])
      expect(dep3[:prod_key]).to eq(product5[:prod_key])
      expect(dep3[:version_requested]).to eq(product5[:version])
      expect(dep3[:version_label]).to eq(product5[:version])
      expect(dep3[:comperator]).to eq('=')
      expect(dep3[:outdated]).to be_falsey
      expect(dep3[:transitive]).to be_truthy
      expect(dep3[:deepness]).to eq(2)
      expect(dep3[:parent_prod_key]).to eq(dep2[:prod_key])
      expect(dep3[:parent_version]).to eq(dep2[:version_label])

      dep4 = proj.dependencies[3]
      expect(dep4[:name]).to eq(product6[:name])
      expect(dep4[:prod_key]).to eq(product6[:prod_key])
      expect(dep4[:version_requested]).to eq(product6[:version])
      expect(dep4[:version_label]).to eq(product6[:version])
      expect(dep4[:comperator]).to eq('=')
      expect(dep4[:outdated]).to be_falsey
      expect(dep4[:transitive]).to be_falsey
      expect(dep4[:deepness]).to eq(0)
      expect(dep4[:parent_prod_key]).to be_nil
      expect(dep4[:parent_version]).to be_nil


      dep5 = proj.dependencies[4]
      expect(dep5[:name]).to eq(product4[:name])
      expect(dep5[:prod_key]).to eq(product4[:prod_key])
      expect(dep5[:version_requested]).to eq(product4[:version])
      expect(dep5[:version_label]).to eq(product4[:version])
      expect(dep5[:comperator]).to eq('=')
      expect(dep5[:outdated]).to be_falsey
      expect(dep5[:transitive]).to be_truthy
      expect(dep5[:deepness]).to eq(1)
      expect(dep5[:parent_id]).to eq(dep4.id)
      expect(dep5[:parent_prod_key]).to eq(dep4[:prod_key])
      expect(dep5[:parent_version]).to eq(dep4[:version_label])

      dep6 = proj.dependencies[5]
      expect(dep6[:name]).to eq(product7[:name])
      expect(dep6[:prod_key]).to eq(product7[:prod_key])
      expect(dep6[:version_requested]).to eq(product7[:version])
      expect(dep6[:version_label]).to eq(product7[:version])
      expect(dep6[:comperator]).to eq('=')
      expect(dep6[:outdated]).to be_falsey
      expect(dep6[:transitive]).to be_truthy
      expect(dep6[:deepness]).to eq(1)
      expect(dep6[:parent_id]).to eq(dep4.id)
      expect(dep6[:parent_prod_key]).to eq(dep4[:prod_key])
      expect(dep6[:parent_version]).to eq(dep4[:version_label])

      dep7 = proj.dependencies[6]
      expect(dep7[:name]).to eq(product4[:name])
      expect(dep7[:prod_key]).to eq(product4[:prod_key])
      expect(dep7[:version_requested]).to eq(product4[:version])
      expect(dep7[:version_label]).to eq(product4[:version])
      expect(dep7[:comperator]).to eq('=')
      expect(dep7[:outdated]).to be_falsey
      expect(dep7[:transitive]).to be_falsey
      expect(dep7[:deepness]).to eq(0)
      expect(dep7[:parent_prod_key]).to be_nil
      expect(dep7[:parent_version]).to be_nil

      dep8 = proj.dependencies[7]
      expect(dep8[:name]).to eq(product8[:name])
      expect(dep8[:prod_key]).to eq(product8[:prod_key])
      expect(dep8[:version_requested]).to eq(product8[:version])
      expect(dep8[:version_label]).to eq(product8[:version])
      expect(dep8[:comperator]).to eq('=')
      expect(dep8[:outdated]).to be_falsey
      expect(dep8[:transitive]).to be_falsey
      expect(dep8[:deepness]).to eq(0)
      expect(dep8[:parent_prod_key]).to be_nil
      expect(dep8[:parent_version]).to be_nil

      dep9 = proj.dependencies[8]
      expect(dep9[:name]).to eq(product4[:name])
      expect(dep9[:prod_key]).to eq(product4[:prod_key])
      expect(dep9[:version_requested]).to eq(product4[:version])
      expect(dep9[:version_label]).to eq(product4[:version])
      expect(dep9[:comperator]).to eq('=')
      expect(dep9[:outdated]).to be_falsey
      expect(dep9[:transitive]).to be_truthy
      expect(dep9[:deepness]).to eq(1)
      expect(dep9[:parent_id]).to eq(dep8.id)
      expect(dep9[:parent_prod_key]).to eq(dep8[:prod_key])
      expect(dep9[:parent_version]).to eq(dep8[:version_label])


    end
  end
end
