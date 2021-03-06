require File.expand_path('../test_helper', __FILE__)

module Inquisitio

  class Elephant
    attr_accessor :id, :name

    def initialize(_id, _name)
      @id, @name = _id, _name
    end
  end

  class Giraffe
    attr_accessor :id, :name

    def initialize(_id, _name)
      @id, @name = _id, _name
    end
  end

  class SearcherTest < Minitest::Test
    def setup
      super
      @search_endpoint = 'http://my.search-endpoint.com'
      Inquisitio.config.search_endpoint = @search_endpoint
      Inquisitio.config.api_version = nil
      @result_1 = {'data' => {'id' => ['1'], 'title' => ['Foobar'], 'type' => ['Cat']}}
      @result_2 = {'data' => {'id' => ['2'], 'title' => ['Foobar'], 'type' => ['Cat']}}
      @result_3 = {'data' => {'id' => ['20'], 'title' => ['Foobar2'], 'type' => ['Module_Dog']}}
      @expected_results = [@result_1, @result_2, @result_3]
      @start = 5
      @found = 8

      @body = {
          'status' => {
              'rid' => '9d3b24b0e3399866dd8d376a7b1e0f6e930d55830b33a474bfac11146e9ca1b3b8adf0141a93ecee',
              'time-ms' => 3
          },
          'hits' => {
              'found' => @found,
              'start' => @start,
              'hit' => @expected_results,
          }
      }.to_json

      Excon.defaults[:mock] = true
      Excon.stub({}, {body: @body, status: 200})
    end

    def teardown
      super
      Excon.stubs.clear
    end

    def test_where_sets_variable
      criteria = 'Star Wars'
      searcher = Searcher.where(criteria)
      assert_equal [criteria], searcher.params[:query_terms]
    end

    def test_where_sets_variable_with_an_array
      criteria = %w(Star Wars)
      searcher = Searcher.where(criteria)
      assert_equal criteria, searcher.params[:query_terms]
    end

    def test_where_doesnt_mutate_searcher
      initial_criteria = 'star wars'
      searcher = Searcher.where(initial_criteria)
      searcher.where('Return of the Jedi')
      assert_equal [initial_criteria], searcher.params[:query_terms]
    end

    def test_where_returns_a_new_searcher
      searcher1 = Searcher.where('star wars')
      searcher2 = searcher1.where('star wars')
      refute_same searcher1, searcher2
    end

    def test_where_sets_named_fields
      named_fields = {genre: 'Animation'}
      searcher = Searcher.where(named_fields)
      assert_equal({genre: ['Animation']}, searcher.params[:query_named_fields])
    end

    def test_where_merges_named_fields
      named_fields1 = {genre: 'Animation'}
      named_fields2 = {foobar: 'Cat'}
      searcher = Searcher.where(named_fields1).where(named_fields2)
      assert_equal({genre: ['Animation'], foobar: ['Cat']}, searcher.params[:query_named_fields])
    end

    def test_symbolizes_where_keys
      named_fields1 = {'genre' => 'Animation'}
      named_fields2 = {'foobar' => 'Cat'}
      searcher = Searcher.where(named_fields1).where(named_fields2)
      assert_equal({genre: ['Animation'], foobar: ['Cat']}, searcher.params[:query_named_fields])
    end

    def test_where_merges_named_fields_with_same_key
      named_fields1 = {genre: 'Animation'}
      named_fields2 = {genre: 'Action'}
      searcher = Searcher.where(named_fields1).where(named_fields2)
      assert_equal({genre: %w(Animation Action)}, searcher.params[:query_named_fields])
    end

    def test_where_gets_correct_url
      searcher = Searcher.where('Star Wars')
      search_url = searcher.send(:search_url)
      assert(search_url.include?('q=Star+Wars'), "Search url should include search term: #{search_url}")
    end

    def test_where_gets_correct_url_with_fields_in_search
      searcher = Searcher.where(title: 'Star Wars')
      search_url = searcher.send(:search_url)
      assert /(\?|&)q=title%3A%27Star\+Wars%27(&|$)/ =~ search_url, "Search url should include query: #{search_url}"
      assert /(\?|&)q.parser=structured(&|$)/ =~ search_url, "Search url should include parser: #{search_url}"
    end

    def test_where_works_with_array_in_a_hash
      criteria = {thing: %w(foo bar)}
      searcher = Searcher.where(criteria)
      assert_equal criteria, searcher.params[:query_named_fields]
    end

    def test_where_works_with_string_and_array
      str_criteria = 'Star Wars'
      hash_criteria = {thing: %w(foo bar)}
      searcher = Searcher.where(str_criteria).where(hash_criteria)
      assert_equal hash_criteria, searcher.params[:query_named_fields]
      assert_equal [str_criteria], searcher.params[:query_terms]
    end

    def test_per_doesnt_mutate_searcher
      searcher = Searcher.per(10)
      searcher.per(15)
      assert_equal 10, searcher.params[:per]
    end

    def test_per_returns_a_new_searcher
      searcher1 = Searcher.where('star wars')
      searcher2 = searcher1.where('star wars')
      refute_same searcher1, searcher2
    end

    def test_per_sets_variable
      searcher = Searcher.per(15)
      assert_equal 15, searcher.params[:per]
    end

    def test_per_parses_a_string
      searcher = Searcher.per('15')
      assert_equal 15, searcher.params[:per]
    end

    def test_per_gets_correct_url
      searcher = Searcher.per(15)
      assert searcher.send(:search_url).include? '&size=15'
    end

    def test_page_doesnt_mutate_searcher
      searcher = Searcher.page(1)
      searcher.page(2)
      assert_equal 1, searcher.params[:page]
    end

    def test_page_returns_a_new_searcher
      searcher1 = Searcher.page(1)
      searcher2 = searcher1.page(2)
      refute_same searcher1, searcher2
    end

    def test_page_sets_variable
      searcher = Searcher.page(3)
      assert_equal 3, searcher.params[:page]
    end

    def test_page_parses_a_string
      searcher = Searcher.page('15')
      assert_equal 15, searcher.params[:page]
    end

    def test_page_gets_correct_url
      searcher = Searcher.page(3).per(15)
      assert searcher.send(:search_url).include? '&start=30'
    end

    def test_that_starts_at_zero
      searcher = Searcher.where('foo')
      refute searcher.send(:search_url).include? '&start='
    end

    def test_returns_doesnt_mutate_searcher
      searcher = Searcher.returns(:foobar)
      searcher.returns(:dogcat)
      assert_equal [:foobar], searcher.params[:returns]
    end

    def test_returns_returns_a_new_searcher
      searcher1 = Searcher.returns(1)
      searcher2 = searcher1.returns(2)
      refute_same searcher1, searcher2
    end

    def test_returns_sets_variable
      searcher = Searcher.returns('foobar')
      assert searcher.params[:returns].include?('foobar')
    end

    def test_returns_gets_correct_url_returns_appends_variable
      searcher = Searcher.returns('foobar')
      assert searcher.send(:search_url).include? '&return=foobar'
    end

    def test_returns_with_array_sets_variable
      searcher = Searcher.returns('dog', 'cat')
      assert_equal %w(dog cat), searcher.params[:returns]
    end

    def test_returns_with_array_gets_correct_url
      searcher = Searcher.returns('id', 'foobar')
      search_url = searcher.send(:search_url)
      assert(search_url.include?('&return=id%2Cfoobar'), "Search url should include return: #{search_url}")
    end

    def test_returns_appends_variable
      searcher = Searcher.returns('id').returns('foobar')
      assert_equal %w(id foobar), searcher.params[:returns]
    end

    def test_search_calls_search_url_builder
      SearchUrlBuilder.any_instance.expects(build: 'http://www.example.com')
      searcher = Searcher.where('Star Wars')
      searcher.search
    end

    def test_search_raises_exception_when_response_not_200
      Excon.stub({}, {:body => 'Bad Happened', :status => 500})

      searcher = Searcher.where('Star Wars')
      searcher.instance_variable_set(:@failed_attempts, 3)

      assert_raises(InquisitioError, 'Search failed with status code 500') do
        searcher.search
      end
    end

    def test_search_raises_exception_when_excon_exception_thrown
      Excon.stub({}, lambda { |_| raise Excon::Errors::Timeout })

      searcher = Searcher.where('Star Wars')
      searcher.instance_variable_set(:@failed_attempts, 3)

      assert_raises(InquisitioError) do
        searcher.search
      end
    end

    def test_search_retries_when_failed_attempts_under_limit
      Excon.expects(:get).raises(Excon::Errors::Timeout).times(3)

      searcher = Searcher.where('Star Wars')
      assert_raises(InquisitioError, 'Search failed with status code 500') do
        searcher.search
      end
    end

    def test_that_iterating_calls_results
      searcher = Searcher.where('star_wars')
      searcher.expects(results: [])
      searcher.each {}
    end

    def test_that_iterating_calls_each
      searcher = Searcher.where('star_wars')
      searcher.search
      searcher.send(:results).expects(:each)
      searcher.each {}
    end

    def test_that_select_calls_each
      searcher = Searcher.where('star_wars')
      searcher.search
      searcher.send(:results).expects(:select)
      searcher.select {}
    end

    def test_search_should_set_results
      searcher = Searcher.where('star_wars')
      searcher.search
      assert_equal @expected_results, searcher.instance_variable_get('@results')
    end

    def test_search_should_create_a_results_object
      searcher = Searcher.where('star_wars')
      searcher.search
      assert Results, searcher.instance_variable_get('@results').class
    end

    def test_search_only_runs_once
      searcher = Searcher.where('star_wars')
      Excon.expects(:get).returns(mock(status: 200, body: @body)).once
      2.times { searcher.search }
    end

    def test_should_not_specify_return_by_default
      searcher = Searcher.where('Star Wars')
      assert_equal [], searcher.params[:returns]
      refute searcher.send(:search_url).include? '&return='
    end

    def test_should_return_ids
      searcher = Searcher.where('Star Wars')
      assert_equal [1, 2, 20], searcher.ids
    end

    def test_should_return_records_in_results_order
      expected_1 = Elephant.new(2, 'Sootica')
      expected_2 = Giraffe.new(20, 'Wolf')
      expected_3 = Elephant.new(1, 'Gobbolino')

      Elephant.expects(:where).with(id: %w(2 1)).returns([expected_3, expected_1])
      Giraffe.expects(:where).with(id: ['20']).returns([expected_2])

      searcher = Searcher.new
      result = [
          {'data' => {'id' => ['2'], 'type' => ['Inquisitio_Elephant']}},
          {'data' => {'id' => ['20'], 'type' => ['Inquisitio_Giraffe']}},
          {'data' => {'id' => ['1'], 'type' => ['Inquisitio_Elephant']}}
      ]
      searcher.instance_variable_set('@results', result)
      expected_records = [expected_1, expected_2, expected_3]
      actual_records = searcher.records
      assert_equal expected_records, actual_records
    end

    def test_should_sort_field_ascending
      searcher = Searcher.where('Star Wars').sort(year: :asc)
      search_url = searcher.send(:search_url)
      assert search_url.include?('sort=year%20asc'), "search url should include sort parameter:\n#{search_url}"
    end

    def test_should_sort_field_descending
      searcher = Searcher.where('Star Wars').sort(year: :desc)
      search_url = searcher.send(:search_url)
      assert search_url.include?('sort=year%20desc'), "search url should include sort parameter:\n#{search_url}"
    end

    def test_should_sort_multiple_fields
      searcher = Searcher.where('Star Wars').sort(year: :desc, foo: :asc)
      search_url = searcher.send(:search_url)
      assert search_url.include?('sort=year%20desc,foo%20asc'), "search url should include sort parameter:\n#{search_url}"
    end

    def test_should_default_to_empty_options
      searcher = Searcher.where('Star Wars')
      search_url = searcher.send(:search_url)
      refute search_url.include?('q.options='), "search url should not include q.options parameter:\n#{search_url}"
    end

    def test_should_support_options
      searcher = Searcher.where('Star Wars').options(fields: %w(title^2 plot^0.5))
      search_url = searcher.send(:search_url)
      assert search_url.include?('q.options=%7B%22fields%22%3A%5B%22title%5E2%22%2C%22plot%5E0.5%22%5D%7D'), "search url should include q.options parameter:\n#{search_url}"
    end

    def test_should_support_operator_in_options
      searcher = Searcher.where('Star Wars').options(defaultOperator: 'or')
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)q.options=%7B%22defaultOperator%22%3A%22or%22%7D(&|$)/, "search url should include q.options parameter:\n#{search_url}"
    end

    def test_options_doesnt_mutate_searcher
      searcher = Searcher.where('star wars')
      searcher.options(fields: %w(title^2.0 plot^0.5))
      search_url = searcher.send(:search_url)
      refute search_url.include?('q.options='), "search url should not include q.options parameter:\n#{search_url}"
    end

    def test_should_default_to_no_expressions
      searcher = Searcher.where('Star Wars')
      search_url = searcher.send(:search_url)
      refute search_url =~ /(\?|&)expr\./, "search url should not include any expr. parameters:\n#{search_url}"
    end

    def test_expressions_should_not_mutate_searcher
      searcher = Searcher.where('star wars')
      searcher.expressions(rank1: 'log10(clicks)*_score')
      search_url = searcher.send(:search_url)
      refute search_url =~ /(\?|&)expr\.rank1=log10%28clicks%29%2A_score(&|$)/, "search url should not include rank1 expr. parameter:\n#{search_url}"
      refute search_url =~ /(\?|&)expr\./, "search url should not include any expr. parameters:\n#{search_url}"
    end

    def test_should_add_one_expression_to_search
      searcher = Searcher.where('star wars').expressions(rank1: 'log10(clicks)*_score')
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)expr\.rank1=log10%28clicks%29%2A_score(&|$)/, "search url should include expr.rank1 parameter:\n#{search_url}"
    end

    def test_should_add_more_than_one_expression_to_search
      searcher = Searcher.where('star wars').expressions(rank1: 'log10(clicks)*_score', rank2: 'cos( _score)')
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)expr\.rank1=log10%28clicks%29%2A_score(&|$)/, "search url should include expr.rank1 parameter:\n#{search_url}"
      assert search_url =~ /(\?|&)expr\.rank2=cos%28\+_score%29(&|$)/, "search url should include expr.rank1 parameter:\n#{search_url}"
    end

    def test_should_support_structured_parser
      searcher = Searcher.where('star wars').parser(:structured)
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)q\.parser=structured(&|$)/, "search url should include q.parser parameter:\n#{search_url}"
    end

    def test_should_support_any_parser
      searcher = Searcher.where('star wars').parser(:foo_bar_baz)
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)q\.parser=foo_bar_baz(&|$)/, "search url should include q.parser parameter:\n#{search_url}"
    end

    def test_should_not_have_fq_if_no_filter
      searcher = Searcher.where('star wars')
      search_url = searcher.send(:search_url)
      refute search_url =~ /(\?|&)fq=/, "search url should not include fq parameter:\n#{search_url}"
    end

    def test_should_take_a_filter_query
      searcher = Searcher.where('star wars').filter('a new hope')
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)fq=a\+new\+hope(&|$)/, "search url should include fq parameter:\n#{search_url}"
    end

    def test_should_take_a_filter_query_with_fields
      searcher = Searcher.where('star wars').filter(tags: 'anewhope')
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)fq=tags%3A%27anewhope%27(&|$)/, "search url should include fq parameter:\n#{search_url}"
    end

    def test_should_accept_empty_filter_to_reset_filters
      searcher = Searcher.where('star wars').filter(tags: 'anewhope').filter(nil)
      search_url = searcher.send(:search_url)
      refute search_url =~ /(\?|&)fq=tags%3A%27anewhope%27(&|$)/, "search url should not include fq parameter:\n#{search_url}"
    end

    def test_should_tolerate_empty_filter
      searcher = Searcher.where('star wars').filter(nil)
      search_url = searcher.send(:search_url)
      refute search_url =~ /(\?|&)fq=/, "search url should not include fq parameter:\n#{search_url}"
    end

    def test_should_take_a_facet
      searcher = Searcher.where('star wars').facets(tags: {})
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)facet\.tags=%7B%7D(&|$)/, "search url should include facet.tags parameter:\n#{search_url}"
    end

    def test_should_take_facets
      searcher = Searcher.where('star wars').facets(tags: {}, genre: {sort:'bucket', size:5})
      search_url = searcher.send(:search_url)
      assert search_url =~ /(\?|&)facet\.tags=%7B%7D(&|$)/, "search url should include facet.tags parameter:\n#{search_url}"
      assert search_url =~ /(\?|&)facet\.genre=%7B%22sort%22%3A%22bucket%22%2C%22size%22%3A5%7D(&|$)/, "search url should include facet.genre parameter:\n#{search_url}"
    end

  end
end
