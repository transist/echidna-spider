require 'spec_helper'

describe RedisModel do
  before do
    class Post
      include RedisModel
    end
  end

  let(:attributes) { {title: 'Title', body: 'Body'} }
  let(:post) { Post.new(attributes) }

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

  describe '#save' do
    before do
      post.save
    end

    it 'should save the model instance' do
      loaded_attrs = $redis.hgetall(post.key)
      expect(loaded_attrs).to eq(attributes)
    end

    it 'should add model key to models set' do
      post_keys = $redis.smembers(:posts)
      expect(post_keys).to include(post.key)
    end
  end
end
