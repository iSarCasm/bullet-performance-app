# Issue

There is a performance issue when using `preload` for large amount of rows. Even though, the request itself may be very fast there is a very large amount of time spent in `Bullet::Rack` part. Example code:

`@comments = Comment.preload(:article).first(5_000)`

## With bullet turned OFF:
```
Completed 200 OK in 652ms (Views: 409.3ms | ActiveRecord: 60.8ms | Allocations: 807853)
```
Request completed in ~0.6 seconds
<img width="624" alt="vnd m  Other" src="https://user-images.githubusercontent.com/1886857/152996691-d298ca7e-62a0-4f0e-be42-72be9653c48b.png">

Ruby-Prof flat output:
```
Measure Mode: wall_time
Thread ID: 14120
Fiber ID: 15100
Total: 1.916769
Sort by: self_time

 %self      total      self      wait     child     calls  name                           location
 16.54      0.317     0.317     0.000     0.000    10020   IO#write                       
  4.06      0.078     0.078     0.000     0.000        9   PG::Result#values              
  3.07      1.916     0.059     0.000     1.857    71567  *Array#each                     
  2.13      0.041     0.041     0.000     0.000        1   PG::Connection#exec_params     
  1.57      0.433     0.030     0.000     0.403    15020   ActiveSupport::LoggerThreadSafeLevel#add /Users/igortsykalo/.rbenv/versions/2.7.5/lib/ruby/gems/2.7.0/gems/activesupport-7.0.1/lib/active_support/logger_thread_safe_level.rb:50
  1.56      0.186     0.030     0.000     0.156    70719  *Class#new                      
  1.50      0.078     0.029     0.000     0.049   125484  *Hash#fetch                     
  1.26      0.070     0.024     0.000     0.046    35000   ActiveRecord::AttributeMethods#respond_to? /Users/igortsykalo/.rbenv/versions/2.7.5/lib/ruby/gems/2.7.0/gems/activerecord-7.0.1/lib/active_record/attribute_methods.rb:207
  1.15      0.022     0.022     0.000     0.000        7   PG::Connection#async_exec      
  1.14      0.022     0.022     0.000     0.000   169832   Module#===                     
  1.08      0.023     0.021     0.000     0.003       43   <Module::Bootsnap::CompileCache::Native>#fetch 
```
_Full profiling information can be found here: https://github.com/iSarCasm/bullet-performance-app/tree/main/rubyprof_

## With bullet turned ON:
```
Completed 200 OK in 1095ms (Views: 643.1ms | ActiveRecord: 60.2ms | Allocations: 1857914)
```
Request completed in ~10 seconds
<img width="639" alt="Pasted Graphic" src="https://user-images.githubusercontent.com/1886857/152996884-ffd3abd3-30d2-4611-8c24-e454aade828a.png">

Ruby-Prof flat output:
```
Measure Mode: wall_time
Thread ID: 14340
Fiber ID: 15100
Total: 45.175374
Sort by: self_time

 %self      total      self      wait     child     calls  name                           location
 21.73     16.381     9.816     0.000     6.565 25000015   Set#merge                      /Users/igortsykalo/.rbenv/versions/2.7.5/lib/ruby/2.7.0/set.rb:422
 19.01     39.600     8.589     0.000    31.010   276582  *Array#each                     
 11.75      8.288     5.309     0.000     2.980 25005000   <Class::Bullet::Detector::Association>#call_object_associations /Users/igortsykalo/.rbenv/versions/2.7.5/lib/ruby/gems/2.7.0/gems/bullet-7.0.1/lib/bullet/detector/association.rb:62
  7.68      3.469     3.469     0.000     0.000 25005000   Bullet::Registry::Base#[]      /Users/igortsykalo/.rbenv/versions/2.7.5/lib/ruby/gems/2.7.0/gems/bullet-7.0.1/lib/bullet/registry/base.rb:12
  6.97      4.516     3.151     0.000     1.365    25079  *Array#hash                     
  4.70      2.121     2.121     0.000     0.000 25000004   Hash#update                    
  3.71      1.675     1.674     0.000     0.000 25100087   Thread#[]                      
  3.59      1.622     1.622     0.000     0.000 25005027   Kernel#instance_of?            
  3.22      1.453     1.453     0.000     0.000 25010014   Kernel#instance_variable_get   
  3.18      1.434     1.434     0.000     0.000 26205193   Kernel#class                   
  3.01      1.360     1.359     0.000     0.000 25025185   String#hash                    
  2.93      1.324     1.324     0.000     0.000 25170467   <Class::Thread>#current        
  1.56      0.706     0.706     0.000     0.000     5014   Array#flatten   
```
_Full profiling information can be found here: https://github.com/iSarCasm/bullet-performance-app/tree/main/rubyprof_

### Possible problem

This is probablt caused by `UnusedEagerLoading` detector (https://github.com/flyerhzm/bullet/blob/master/lib/bullet/detector/unused_eager_loading.rb) which seems to have O(n^2) time complexity since there are *25000015* `Set#merge` invocation which is ~`5000*5000` (5000 Comments with 5000 Articles loaded in 2 DB queries).


# Application

Steps to reproduce the issue

1. `rails new --database=postgresql bullet-performance-app`
2. `be rails generate scaffold Article title:string body:text`
3. `be rails generate scaffold Comment body:text author:string article:references`
4. `rails db:migrate`
5. Adjust `_comment.html.erb` to reference Article field `<%= comment.article.title %>`
6. Adjust CommentsController:
```
 def index
    @comments = Comment.preload(:article).first(5_000)
  end
```
7. Add bullet gem
```
  config.after_initialize do
    Bullet.enable = true
    Bullet.rails_logger = true
  end
```
8. Seed database with data:
```
ActiveRecord::Base.connection.transaction do
  articles = 10_000.times.map do
    { title: "Article #{SecureRandom.hex{8}}", body: "Some body" }
  end

  article_ids = Article.upsert_all(articles, returning: [:id]).map { |x| x["id" ]}
  comments = article_ids.map do |ar_id|
    { body:"Comment #{SecureRandom.hex{8}}", author: "Author #{SecureRandom.hex{8}}" , article_id: ar_id }
  end
  Comment.upsert_all(comments)
end
```
10. Notice significant performance issues when accessing `/comments` page AFTER the request has been complete by Rails.
11. Collect profiling information using ruby-prof middleware
```
config.middleware.use Rack::RubyProf, :path => './rubyprof/bullet-on'
```
