program Sample;
var limit: Integer;
function Scale(value, factor: Integer): Integer;
var total, i: Integer;
begin
  total := value * factor;
  for i := 1 to limit do total := total + i;
  Scale := total;
end;
function Twice(value: Integer): Integer;
var total: Integer;
begin
  total := value * 2; { total in a comment }
  Twice := total;
end;
begin
  limit := 3;
  WriteLn('total limit', Scale(limit, 2));
end.
