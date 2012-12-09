classdef OneStepPrediction
   % Class for one-step-ahead prediction

   properties

     path_to_data = '../data/matfiles/All_variables_matched.mat'; % path to data
     predictor_matrix			% raw predictors
     target_matrix			% raw target variables
     target				% lagged univariate target
     design_matrix			% lagged design matrix
     lag = 10;				% lag used to construct data
     active_set = [1:120];		% window of indices on which to fit
     current_y				% current windowed regression target
     current_y_idx = 1;			% target index of current targed
     current_X	     			% current windowed design matrix
     center = 0;
     window_type = 'expanding';
     fit
     pred
     predictions
     test_X
     test_y
     model_selection = 'AIC';	
     AICs
     BICs
     best_AIC
     best_BIC
     best_idx
     coefs
   end

   methods

     % initialize class
     function obj = setup(obj)
       addpath('/glmnet_matlab/');
       obj = obj.load;
       obj = obj.get_lagged_design;
     end

     % load the data
     function obj = load(obj)
     	data_matrix = load(obj.path_to_data);
	obj.predictor_matrix = data_matrix.predictors;
	obj.target_matrix = data_matrix.targets;
     end

     % generate the design matrix of lagged predictors and targets
     function obj = get_lagged_design(obj)
        % get number of predictors
	n_targets = size(obj.target_matrix,2);
        n_inputs = size(obj.predictor_matrix,2);

	% construct lagged design matrix of lag obj.lag
	design_mat = [];
	for i = 1:n_inputs
    	   design_mat = [design_mat lagmatrix( repmat(obj.predictor_matrix(:,i),1,obj.lag+1), obj.lag)];
     	end
	for i = 1:n_targets
    	   design_mat = [design_mat lagmatrix( repmat(obj.target_matrix(:,i),1,obj.lag+1), obj.lag)];
	end
	
	% get lagged design matrix, optionally center and scale the columns
	if obj.center == 1
 	   obj.design_matrix = zscore(design_mat( (obj.lag+1):end,: ));
	else
	   obj.design_matrix = design_mat( (obj.lag+1):end,: );
	end
      end

      % Get active windowed variables, specifying which target variable using 'y_idx'
      function obj = get_current(obj,y_idx)
	% get active windowed regression design matrix and target
	idx = (y_idx-1)*(obj.lag+1)+1;
	obj.current_X = obj.design_matrix(obj.active_set,:);
	obj.current_X(:,idx) = [];
	obj.current_y = obj.design_matrix(obj.active_set,idx);

	% get test points for prediction
	last = obj.active_set(end)
	obj.test_X = obj.design_matrix(last+1,:);
	obj.test_X(:,idx) = [];
	disp(size(obj.test_X)); obj.test_X
	obj.test_y = obj.design_matrix(last+1,idx);
      end
      
      % fit an elasic net regression 
      function obj = get_enet_fit(obj)
        obj.fit = glmnet(obj.current_X, obj.current_y);
        err =  sum((glmnetPredict(obj.fit,'response',obj.current_X) - repmat(obj.current_y,1,length(obj.fit.lambda))).^2)'.*(1/length(obj.current_y))
	disp(err)
	dev = obj.fit.dev;
	df = obj.fit.df;
	n = size(obj.current_X,1);
	AICs = -err + 2*df; obj.AICs = AICs;
	BICs = -err + log(size(obj.current_X,1))*df/n; obj.BICs = BICs;

	if obj.model_selection=='AIC'
	   [best_AIC, best_idx] = min(AICs(2:end));
	   obj.best_AIC = best_AIC;
	   obj.best_idx = best_idx+1; 
	elseif obj.model_selection=='BIC'
	   [best_BIC, best_idx] = min(BICs(2:end));
	   obj.best_BIC = best_BIC;
	   obj.best_idx = best_idx+1; 
	end
        obj.coefs =  glmnetPredict(obj.fit,'coefficients','s', obj.fit.lambda(obj.best_idx));
        obj.pred =  glmnetPredict(obj.fit, 'response', obj.test_X, obj.fit.lambda(obj.best_idx));
      end

      function obj = fit_full_data(obj,window_size)
         % initialize
         n = size(obj.design_matrix,1);
	 n_periods = n - window_size - 1;
	 n_targets = size(obj.target_matrix,2);
	 obj.predictions = zeros(n_periods,n_targets);

	 % run predictions for all periods and all targets
	 for i = 1:n_periods
	    if obj.window_type == 'expanding'
	       obj.active_set = [1:(window_size+i-1)];
	    else
	       obj.active_set = [i:(window_size+i-1)];
	    end
	    for j = 1:n_targets
	        obj = obj.get_current(j);
	    	obj = obj.get_enet_fit;
		obj.predictions(i,j) = obj.pred;
	    end
	 end
      end

   end % methods
end % class     



