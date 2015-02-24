% %%
function [gain] = agc_lut(~)
    n = 100;
    P_in = 1:n;

    lut = ones(n,7);
    lut(:,1) = 1:n;

    % ideal
    max = 82;
    for i = 1:n
        if i < max
            lut(i,2) = 1;
        else
            lut(i,2) = max / P_in(i);
        end
    end
    
    % tanh 1, index 3
    a = 0.015;
    b = 82;
    y_tanh = b .* (1 - exp(-a.*2.*P_in)) ./ (1 + exp(-a.*2.*P_in));
    lut(57:end, 3) = y_tanh(57:end) ./ P_in(57:end);
    
    % tanh 2, index 4
    a = 0.015;
    b = 65; 
    y_tanh = b .* (1 - exp(-a.*2.*P_in)) ./ (1 + exp(-a.*2.*P_in));
    lut(1:end, 4) = y_tanh(1:end) ./ P_in(1:end);
  
    % polynomial 1, index 5
    x_poly = [60 61 105 106];
    y_poly = [60 61 82 82];
    p_coeff = polyfit(x_poly, y_poly, 2);
    yy = polyval(p_coeff, P_in);
    lut(62:end, 5) = yy(62:end) ./ P_in(62:end);
%     lut(105:end, 5) = lut(105:end, 2);
    
    % polynomial 2, index 6
    x_poly = [20 50 51];
    y_poly = [20 45 45];
    p_coeff = polyfit(x_poly, y_poly, 2);
    yy = polyval(p_coeff, P_in);
    lut(44:end, 6) = yy(44:end) ./ P_in(44:end);
    
    % polynomial 3, index 7
    x_poly = [38 56 75 80];
    y_poly = [40 46 42 40];
    p_coeff = polyfit(x_poly, y_poly, 3);
    yy = polyval(p_coeff, P_in);
    lut(43:end, 7) = yy(43:end) ./ P_in(43:end);
    
    % return prefered lookup table
    % 2 = ideal
    % 3 = tanh 1
    % 4 = tanh 2
    % 5 = polynomial 1
    % 6 = polynomial 2
    % 7 = polynomial 3
    gain = lut(:,7);


clf;
figure(2)
subplot(211)
plot(P_in, P_in'.*lut(P_in,2), 'b')
hold on
grid on
plot(P_in, P_in'.*lut(P_in,3), 'g')
plot(P_in, P_in'.*lut(P_in,4), 'g--')
plot(P_in, P_in'.*lut(P_in,5), 'r')
plot(P_in, P_in'.*lut(P_in,6), 'r--')
plot(P_in, P_in'.*lut(P_in,7), 'r.')
legend('2','3','4','5','6','7','Location','northwest')
xlabel('P_{in}')
ylabel('P_{out}')
subplot(212)
plot(P_in, lut(:,2:end))
legend('2','3','4','5','6','7','Location','southwest')
xlabel('P_{in}')
ylabel('gain')
grid on

end

% %% polynomial
% clf
% x_poly = [60 61 105 106];
% y_poly = [60 61 82 82];
% p_coeff = polyfit(x_poly, y_poly, 2);
% xx = linspace(0,130, 131);
% yy = polyval(p_coeff, xx);
% 
% plot(xx,yy, xx,xx,'r--',xx,82,'r--')
% grid on
% axis([0 130 0 85]);

% clf
% x_poly = [40 41 80 81];
% y_poly = [40 41 62 62];
% p_coeff = polyfit(x_poly, y_poly, 2);
% xx = linspace(0,130, 131);
% yy = polyval(p_coeff, xx);
% 
% plot(xx,yy, xx,xx,'r--',xx,82,'r--')
% grid on
% axis([0 130 0 85]);
% 
% 
% % %% tanh
% % clf
% a = 0.015;
% b = 82;
% x = linspace(0,130);
% y = b .* (1 - exp(-a.*2.*x)) ./ (1 + exp(-a.*2.*x));
% hold on
% plot(x,y,'g', x,x,'r--')
% % grid on
% % axis([0 130 0 85]);

% %%
% clf
% a = 0.015;
% b = 75;
% x = linspace(0,130);
% y = b .* (1 - exp(-a.*2.*x)) ./ (1 + exp(-a.*2.*x));
% hold on
% plot(x,y,'g', x,x,'r--',x,82,'r--')
% grid on
% % axis([0 130 0 85]);