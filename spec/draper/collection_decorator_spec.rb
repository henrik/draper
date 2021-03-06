require 'spec_helper'

describe Draper::CollectionDecorator do
  before { ApplicationController.new.view_context }
  subject { Draper::CollectionDecorator.new(source, with: ProductDecorator) }
  let(:source){ [Product.new, Product.new] }
  let(:non_active_model_source){ NonActiveModelProduct.new }

  it "decorates a collection's items" do
    subject.each do |item|
      item.should be_decorated_with ProductDecorator
    end
  end

  it "sets the decorated items' source models" do
    subject.map{|item| item.source}.should == source
  end

  context "with options" do
    subject { Draper::CollectionDecorator.new(source, with: ProductDecorator, some: "options") }

    its(:options) { should == {some: "options"} }

    it "passes options to the individual decorators" do
      subject.each do |item|
        item.options.should == {some: "options"}
      end
    end

    describe "#options=" do
      it "updates the options on the collection decorator" do
        subject.options = {other: "options"}
        subject.options.should == {other: "options"}
      end

      it "updates the options on the individual decorators" do
        subject.options = {other: "options"}
        subject.each do |item|
          item.options.should == {other: "options"}
        end
      end
    end
  end

  describe "#initialize" do
    context "when the :with option is given" do
      context "and the decorator can't be inferred from the class" do
        subject { Draper::CollectionDecorator.new(source, with: ProductDecorator) }

        it "uses the :with option" do
          subject.decorator_class.should be ProductDecorator
        end
      end

      context "and the decorator is inferrable from the class" do
        subject { ProductsDecorator.new(source, with: SpecificProductDecorator) }

        it "uses the :with option" do
          subject.decorator_class.should be SpecificProductDecorator
        end
      end
    end

    context "when the :with option is not given" do
      context "and the decorator can't be inferred from the class" do
        it "raises an UninferrableDecoratorError" do
          expect{Draper::CollectionDecorator.new(source)}.to raise_error Draper::UninferrableDecoratorError
        end
      end

      context "and the decorator is inferrable from the class" do
        subject { ProductsDecorator.new(source) }

        it "infers the decorator" do
          subject.decorator_class.should be ProductDecorator
        end
      end
    end
  end

  describe "#source" do
    it "returns the source collection" do
      subject.source.should be source
    end

    it "is aliased to #to_source" do
      subject.to_source.should be source
    end
  end

  describe "#find" do
    context "with a block" do
      it "decorates Enumerable#find" do
        subject.decorated_collection.should_receive(:find)
        subject.find {|p| p.title == "title" }
      end
    end

    context "without a block" do
      it "decorates Model.find" do
        source.should_not_receive(:find)
        Product.should_receive(:find).with(1).and_return(:product)
        subject.find(1).should == ProductDecorator.new(:product)
      end
    end
  end

  describe "#helpers" do
    it "returns a HelperProxy" do
      subject.helpers.should be_a Draper::HelperProxy
    end

    it "is aliased to #h" do
      subject.h.should be subject.helpers
    end

    it "initializes the wrapper only once" do
      helper_proxy = subject.helpers
      helper_proxy.stub(:test_method) { "test_method" }
      subject.helpers.test_method.should == "test_method"
      subject.helpers.test_method.should == "test_method"
    end
  end

  describe "#localize" do
    before { subject.helpers.should_receive(:localize).with(:an_object, {some: "options"}) }

    it "delegates to helpers" do
      subject.localize(:an_object, some: "options")
    end

    it "is aliased to #l" do
      subject.l(:an_object, some: "options")
    end
  end

  describe ".helpers" do
    it "returns a HelperProxy" do
      subject.class.helpers.should be_a Draper::HelperProxy
    end

    it "is aliased to .h" do
      subject.class.h.should be subject.class.helpers
    end
  end

  describe "#to_ary" do
    # required for `render @collection` in Rails
    it "delegates to the decorated collection" do
      subject.decorated_collection.should_receive(:to_ary).and_return(:an_array)
      subject.to_ary.should == :an_array
    end
  end

  describe "#respond_to?" do
    it "returns true for its own methods" do
      subject.should respond_to :decorated_collection
    end

    it "returns true for the wrapped collection's methods" do
      source.stub(:respond_to?).with(:whatever, true).and_return(true)
      subject.respond_to?(:whatever, true).should be_true
    end
  end

  context "Array methods" do
    describe "#include?" do
      it "delegates to the decorated collection" do
        subject.decorated_collection.should_receive(:include?).with(:something).and_return(true)
        subject.should include :something
      end
    end

    describe "#[]" do
      it "delegates to the decorated collection" do
        subject.decorated_collection.should_receive(:[]).with(42).and_return(:something)
        subject[42].should == :something
      end
    end
  end

  describe "#==" do
    context "when comparing to a collection decorator with the same source" do
      it "returns true" do
        a = Draper::CollectionDecorator.new(source, with: ProductDecorator)
        b = ProductsDecorator.new(source)
        a.should == b
      end
    end

    context "when comparing to a collection decorator with a different source" do
      it "returns false" do
        a = Draper::CollectionDecorator.new(source, with: ProductDecorator)
        b = ProductsDecorator.new([Product.new])
        a.should_not == b
      end
    end

    context "when comparing to a collection of the same items" do
      it "returns true" do
        a = Draper::CollectionDecorator.new(source, with: ProductDecorator)
        b = source.dup
        a.should == b
      end
    end

    context "when comparing to a collection of different items" do
      it "returns true" do
        a = Draper::CollectionDecorator.new(source, with: ProductDecorator)
        b = [Product.new]
        a.should_not == b
      end
    end
  end

  it "pretends to be the source class" do
    subject.kind_of?(source.class).should be_true
    subject.is_a?(source.class).should be_true
  end

  it "is still its own class" do
    subject.kind_of?(subject.class).should be_true
    subject.is_a?(subject.class).should be_true
  end

  describe "#method_missing" do
    before do
      class << source
        def page_number
          42
        end
      end
    end

    it "proxies unknown methods to the source collection" do
      subject.page_number.should == 42
    end
  end

end
