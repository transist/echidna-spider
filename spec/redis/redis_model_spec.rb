require 'spec_helper'

describe RedisModel do
  before do
    class Post
      include RedisModel
    end
  end

  let(:attributes) { {title: 'Title', body: 'Body'} }
  let(:post) { Post.new(attributes) }
  let(:another_post) { Post.new(attributes) }

  context 'finders' do
    describe '.all' do
      it 'should find and return all stored instances' do
        post1 = Post.create(attributes)
        post2 = Post.create(attributes)
        posts = Post.all
        expect(posts).to include(post1)
        expect(posts).to include(post2)
      end
    end

    describe '.find' do
      it 'should load and return stored instance via given key' do
        post = Post.create(attributes)
        expect(Post.find(post.key)).to eq(post)
      end
    end
  end

  describe '.new' do
    it 'should accept attributes hash' do
      Post.new(attributes)
    end
  end

  describe '.create' do
    it 'should return the newly created model instance' do
      post = Post.create(attributes)

      expect(post).to be_a(Post)
    end

    it 'should save the model instance' do
      Post.any_instance.should_receive(:save)
      Post.create(attributes)
    end
  end

  describe '.scope_name' do
    it 'should be the tableized version of class name' do
      expect(Post.scope_name).to eq('posts')
    end
  end

  describe '#scope_name' do
    it 'should be the scope_name of model class' do
      expect(post.scope_name).to eq(Post.scope_name)
    end
  end

  describe '#key' do
    it 'should be combined by the scope name and auto generated id' do
      id = $redis.incr('posts.id')

      expect(post.key).to eq("#{Post.scope_name}/#{id + 1}")

      another_post = Post.new(attributes)
      expect(another_post.key).to eq("#{Post.scope_name}/#{id + 2}")
    end

    it 'should be consistent for same model instance' do
      expect(post.key).to eq(post.key)
    end
  end

  describe '#attributes' do
    it 'should be the attributes used to initialize model instance' do
      expect(post.attributes).to eq(attributes)
    end
  end

  describe '#[]' do
    it 'provide a handy interface for read attributes' do
      expect(post[:title]).to eq(post.attributes[:title])
    end
  end

  describe '#[]=' do
    it 'provide a handy interface for write attributes' do
      post[:title] = 'Another Title'
      expect(post.attributes[:title]).to eq('Another Title')
    end
  end

  describe '#save' do
    before do
      post.save
    end

    it 'should store the model instance as hash with #key' do
      loaded_attrs = $redis.hgetall(post.key)
      expect(loaded_attrs).to eq(attributes)
    end

    it 'should add model key to models set' do
      post_keys = $redis.smembers(:posts)
      expect(post_keys).to include(post.key)
    end
  end

  context 'instance equality' do
    it 'should treat two instances of same model class with same key as ==' do
      post.stub(:key) { 'post/1' }
      another_post.stub(:key) { 'post/1' }

      expect(post).to eq(another_post)
    end

    it 'should delegate #eql? to #==' do
      post.should_receive(:==).with(another_post)
      post.eql?(another_post)
    end
  end

  context 'access attributes with accessor methods' do
    it 'should read attribute' do
      expect(post.title).to eq(post.attributes[:title])
    end

    it 'should write attribute' do
      post.title = 'Another Title'
      expect(post.attributes[:title]).to eq('Another Title')
    end
  end
end
